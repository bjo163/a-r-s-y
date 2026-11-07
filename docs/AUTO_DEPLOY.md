# Automatic deployment to the single VPS

A-R-S-Y deploys the exact commit that triggered GitHub Actions on every push to main, every published GitHub Release, and optional manual workflow runs. It uses native OpenSSH; there is no third-party SSH action or public webhook endpoint.

## 1. Create a dedicated Ed25519 key pair

Run on a trusted workstation, not in the repository:

~~~bash
ssh-keygen -t ed25519 -a 64 -C "github-actions-a-r-s-y" -f ./arsy_deploy -N ""
~~~

Keep arsy_deploy private. Never commit it or paste it into an issue or pull request. arsy_deploy.pub is the public key.

## 2. Install the public key on the VPS

During initial install:

~~~bash
sudo ARSY_DEPLOY_PUBLIC_KEY="$(cat ./arsy_deploy.pub)" bash install.sh
~~~

Or after a normal install:

~~~bash
sudo ARSY_DEPLOY_PUBLIC_KEY="$(cat ./arsy_deploy.pub)" bash /opt/arsy/install.sh --configure-deploy-key
~~~

The installer creates a dedicated arsy-deploy user. Its key is restricted to a forced command, with PTY, agent forwarding, and port forwarding disabled. The forced command accepts only deploy plus a 40-character commit SHA. The account is not added to the Docker group and receives passwordless sudo only for the root-owned deployment script.

## 3. Pin the VPS SSH host key

From the VPS console, inspect the host-key fingerprint:

~~~bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
~~~

From your workstation, obtain the host-key line:

~~~bash
ssh-keyscan -t ed25519 YOUR_VPS_HOST
~~~

Compare the fingerprint from ssh-keyscan with the fingerprint shown in the VPS console. Do not trust an unverified scan. Save the verified known_hosts line.

## 4. Add GitHub Actions repository secrets

Repository → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|---|---|
| ARSY_DEPLOY_HOST | VPS public IP or DNS hostname |
| ARSY_DEPLOY_USER | arsy-deploy |
| ARSY_DEPLOY_SSH_KEY | Full private key file contents from arsy_deploy |
| ARSY_DEPLOY_KNOWN_HOSTS | Verified pinned host-key entry |

Never put a private key in repository variables, tracked files, .env, or workflow YAML.

## 5. Verify automatic deployment

Push a harmless documentation change to main. Open Actions and inspect Deploy A-R-S-Y to single VPS. A successful run connects and calls the restricted deploy command with the triggering commit SHA. Publishing a GitHub Release deploys the commit referenced by that release event, not a moving branch head.

## Safety behavior

- Workflow runs are serialized and do not cancel an active deployment.
- SSH host-key checking is strict and pinned.
- The server fetches main and tags, then checks out the exact target commit.
- Compose config is validated before startup.
- A failed startup or health check attempts to restore the previous commit and stack.
- Successful commit SHA is saved at /var/lib/arsy/deployed-sha; logs are stored in /var/log/arsy/deploy.log.

## Troubleshooting

~~~bash
sudo /opt/arsy/scripts/arsy-doctor.sh
sudo tail -n 200 /var/log/arsy/deploy.log
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml ps
~~~
