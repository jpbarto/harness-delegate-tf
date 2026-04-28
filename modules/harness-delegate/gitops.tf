# ---------------------------------------------------------------------------
# Harness GitOps Agent — registration
#
# Registers the GitOps agent at the *account* level (no org_id / project_id)
# so it is available across all organisations and projects in the account.
# The resource returns an agent_token that the Helm chart needs at start-up.
# ---------------------------------------------------------------------------
resource "harness_platform_gitops_agent" "gitops" {
  identifier = replace("gitops_${local.name_suffix}", "-", "_")
  name       = var.gitops_agent_name
  account_id = var.harness_account_id

  # CONNECTED_ARGO_PROVIDER = Harness manages ArgoCD internally (no existing
  # ArgoCD installation required).
  type = "CONNECTED_ARGO_PROVIDER"

  metadata {
    namespace         = kubernetes_namespace.harness_gitops.metadata[0].name
    high_availability = false
  }
}

# ---------------------------------------------------------------------------
# Redis password — generated once, stored in state, never rotated unless
# the resource is tainted.  Passed to harness.secrets.redisPassword so the
# ArgoCD-internal Redis and the redisSecretInit job agree on the same value.
# ---------------------------------------------------------------------------
resource "random_password" "gitops_redis" {
  length           = 16
  special          = true
  override_special = "_-"
}

# ---------------------------------------------------------------------------
# Harness GitOps Agent — Helm deployment
#
# Values mirror the override.yaml Harness generates in the UI.
# Terraform-managed values (agent token, identifier, redis password, names)
# are substituted in place of the static strings in the UI download.
#
# References:
#   https://github.com/harness/gitops-helm/blob/main/values.yaml
#   https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml
# ---------------------------------------------------------------------------
resource "helm_release" "harness_gitops_agent" {
  name             = "harness-gitops-agent"
  repository       = "https://harness.github.io/helm-gitops"
  chart            = "gitops"
  namespace        = kubernetes_namespace.harness_gitops.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600
  cleanup_on_fail  = true

  depends_on = [
    kubernetes_cluster_role_binding.harness_gitops_agent_admin,
    kubernetes_service_account.harness_gitops_agent,
    harness_platform_gitops_agent.gitops,
  ]

  values = [
    yamlencode({
      # -----------------------------------------------------------------------
      # ArgoCD image — Harness-certified build
      # -----------------------------------------------------------------------
      global = {
        image = {
          repository = "docker.io/harness/argocd"
          tag        = "v3.3.0"
        }
      }

      # -----------------------------------------------------------------------
      # Harness identity + connectivity
      # -----------------------------------------------------------------------
      harness = {
        identity = {
          accountIdentifier = var.harness_account_id
          orgIdentifier     = ""
          projectIdentifier = ""
          # Computed by the registration resource above.
          agentIdentifier = harness_platform_gitops_agent.gitops.identifier
        }

        secrets = {
          agentSecret = harness_platform_gitops_agent.gitops.agent_token
          caData = {
            enabled = false
            secret  = ""
          }
          # Stable random password shared between Redis and redisSecretInit.
          redisPassword = random_password.gitops_redis.result
        }

        gitopsServerHost   = "${var.harness_manager_endpoint}/prod1/gitops"
        networkPolicy      = { create = true }
        createClusterRoles = true

        configMap = {
          logLevel = "DEBUG"

          http = {
            agentHttpTarget = "${var.harness_manager_endpoint}/gitops"
            tlsEnabled      = false
            certPath        = "/tmp/ca.bundle"
          }

          reconcile = {
            appsetReconcile = true
          }
        }

        disasterRecovery    = { enabled = false, identifier = "" }
        openshift           = { enabled = false }
        flux                = { enabled = false }
        argocdHarnessPlugin = { enabled = false }
      }

      # -----------------------------------------------------------------------
      # ArgoCD sub-chart
      # The key contains a hyphen so it must be quoted in HCL.
      # -----------------------------------------------------------------------
      "argo-cd" = {
        enabled = true

        crds = {
          install = true
          keep    = true
        }

        configs = {
          cm = {
            "cluster.inClusterEnabled" = "true"
          }
        }

        controller = {
          resources = {
            requests = { cpu = "1", memory = "3Gi" }
            limits   = { cpu = "2", memory = "3Gi" }
          }
        }

        applicationSet = {
          resources = {
            requests = { cpu = "500m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }
        }

        redis = {
          enabled = true
          image = {
            repository = "docker.io/harness/redis"
            tag        = "7.4.8"
          }
          resources = {
            requests = { cpu = "500m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }
        }

        redisSecretInit = { enabled = true }

        "redis-ha" = {
          enabled = false
          image = {
            repository = "docker.io/harness/redis"
            tag        = "7.4.8"
          }
          haproxy = {
            enabled = false
            image = {
              repository = "docker.io/harness/haproxy"
              tag        = "3.2.14-alpine3.23"
            }
          }
          configmapTest = {
            image = {
              repository = "docker.io/harness/shellcheck"
              tag        = "v0.11.0"
            }
          }
          resources = {
            requests = { cpu = "500m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }
        }

        repoServer = {
          replicas = 1
          resources = {
            requests = { cpu = "1", memory = "3Gi" }
            limits   = { cpu = "2", memory = "3Gi" }
          }

          env = [
            { name = "HELM_PLUGINS",                             value = "/helm-sops-tools/helm-plugins/" },
            { name = "HELM_SECRETS_CURL_PATH",                   value = "/helm-sops-tools/curl" },
            { name = "HELM_SECRETS_SOPS_PATH",                   value = "/helm-sops-tools/sops" },
            { name = "HELM_SECRETS_KUBECTL_PATH",                value = "/helm-sops-tools/kubectl" },
            { name = "HELM_SECRETS_BACKEND",                     value = "sops" },
            { name = "HELM_SECRETS_VALUES_ALLOW_SYMLINKS",       value = "false" },
            { name = "HELM_SECRETS_VALUES_ALLOW_ABSOLUTE_PATH",  value = "true" },
            { name = "HELM_SECRETS_VALUES_ALLOW_PATH_TRAVERSAL", value = "false" },
            { name = "HELM_SECRETS_WRAPPER_ENABLED",             value = "true" },
            { name = "HELM_SECRETS_HELM_PATH",                   value = "/usr/local/bin/helm" },
            { name = "PATH",                                     value = "/helm-sops-tools/helm-secrets:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" },
          ]

          initContainers = [
            {
              name            = "sops-helm-secrets-tool"
              image           = "docker.io/harness/gitops-agent-installer-helper:v0.0.13"
              imagePullPolicy = "IfNotPresent"
              resources = {
                requests = { cpu = "500m", memory = "512Mi" }
                limits   = { cpu = "500m", memory = "512Mi" }
              }
              command = ["sh", "-ec"]
              args = [
                join("\n", [
                  "cp -r /custom-tools/. /helm-sops-tools",
                  "cp /helm-sops-tools/helm-plugins/helm-secrets/scripts/wrapper/helm.sh /helm-sops-tools/helm",
                  "mkdir -p /helm-sops-tools/helm-secrets && cp /helm-sops-tools/helm-plugins/helm-secrets/scripts/wrapper/helm.sh /helm-sops-tools/helm-secrets/helm",
                  "chmod +x /helm-sops-tools/helm-secrets/*",
                  "chmod +x /helm-sops-tools/*",
                ])
              ]
              volumeMounts = [
                { mountPath = "/helm-sops-tools", name = "helm-sops-tools" }
              ]
            }
          ]

          extraContainers = [
            {
              command         = ["/var/run/argocd/argocd-cmp-server"]
              image           = "docker.io/harness/gitops-agent-installer-helper:v0.0.13"
              imagePullPolicy = "IfNotPresent"
              name            = "argocd-harness-plugin"
              resources = {
                requests = { cpu = "500m", memory = "512Mi" }
                limits   = { cpu = "500m", memory = "512Mi" }
              }
              securityContext = {
                capabilities = { drop = ["NET_RAW"] }
                runAsGroup   = 999
                runAsUser    = 999
              }
              terminationMessagePath   = "/dev/termination-log"
              terminationMessagePolicy = "File"
              volumeMounts = [
                { mountPath = "/var/run/argocd",                             name = "var-files" },
                { mountPath = "/home/argocd/cmp-server/plugins",             name = "plugins" },
                { mountPath = "/tmp",                                         name = "tmp" },
                { mountPath = "/home/argocd/cmp-server/config/plugin.yaml",  name = "argocd-harness-plugin", subPath = "harness.yaml" },
              ]
            }
          ]
        }
      }

      # -----------------------------------------------------------------------
      # GitOps agent pod
      # -----------------------------------------------------------------------
      agent = {
        # Display name shown in the Harness UI — matches the registered name.
        harnessName = var.gitops_agent_name
        image = {
          repository = "docker.io/harness/gitops-agent"
          tag        = "v0.115.0"
        }
        replicas = 1
        resources = {
          requests = { cpu = "500m", memory = "512Mi" }
          limits   = { cpu = "1", memory = "1Gi" }
        }
        fipsEnabled      = false
        autoscaling      = { enabled = false }
        highAvailability = false
        proxy = {
          enabled    = false
          httpProxy  = ""
          httpsProxy = ""
        }

        # Reuse the pre-created service account bound to cluster-admin.
        serviceAccount = {
          create = false
          name   = kubernetes_service_account.harness_gitops_agent.metadata[0].name
        }
      }

      # -----------------------------------------------------------------------
      # Upgrader — keeps the agent image current automatically.
      # -----------------------------------------------------------------------
      upgrader = {
        enabled = true
        image   = "docker.io/harness/upgrader:latest"
        config = {
          proxyHost     = ""
          proxyPort     = ""
          proxyScheme   = ""
          noProxy       = ""
          proxyUser     = ""
          proxyPassword = ""
        }
      }
    })
  ]
}
