# Authenticate users against OpenShift OAuth provider.

if os.environ['JUPYTERHUB_PROJECT'] != os.environ['JUPYTERHUB_NAMESPACE']:
    raise ValueError(f"JUPYTERHUB_PROJECT template variable does not match actual launch namespace!  {os.environ['JUPYTERHUB_PROJECT']} != {os.environ['JUPYTERHUB_NAMESPACE']}")

c.JupyterHub.authenticator_class = "openshift"

from oauthenticator.openshift import OpenShiftOAuthenticator
OpenShiftOAuthenticator.scope = ['user:full']

client_id = os.environ['OAUTH_CLIENT_ID']
client_secret = os.environ['OAUTH_CLIENT_SECRET']

c.OpenShiftOAuthenticator.client_id = client_id
c.OpenShiftOAuthenticator.client_secret = client_secret
c.Authenticator.enable_auth_state = True

from base64 import b64encode
hex_key = os.environ['JUPYTERHUB_ENCRYPTION_KEY']
c.CryptKeeper.keys = [ b64encode(bytes.fromhex(hex_key)).decode() ]

c.OpenShiftOAuthenticator.openshift_auth_api_url = \
    os.environ['OPENSHIFT_AUTH_API_URL']
c.OpenShiftOAuthenticator.openshift_rest_api_url = \
    os.environ['OPENSHIFT_REST_API_URL']
c.OpenShiftOAuthenticator.oauth_callback_url = \
    f"https://{public_hostname}/hub/oauth_callback"

# TODO: Kubernetes API Cert is self-signed, but we should be able to configure
#       the trust relationship rather than disabling this.  There is no need to
#       disable the OAuth cert validation--it is externally verifiable already,
#       but this single flag controls cert validation for both APIs...
c.OpenShiftOAuthenticator.validate_cert = False

# Add any additional JupyterHub configuration settings.

c.KubeSpawner.extra_labels = {
    'spawner': 'workspace',
    'class': 'session',
    'user': '{username}'
}
c.KubeSpawner.storage_extra_labels = {
    'spawner': 'workspace',
    'user': '{username}'
}

# Set up list of registered users and any users nominated as admins.

if os.path.exists('/opt/app-root/configs/admin_users.txt'):
    with open('/opt/app-root/configs/admin_users.txt') as fp:
        content = fp.read().strip()
        if content:
            c.Authenticator.admin_users = set(content.split())

if os.path.exists('/opt/app-root/configs/user_whitelist.txt'):
    with open('/opt/app-root/configs/user_whitelist.txt') as fp:
        c.Authenticator.whitelist = set(fp.read().strip().split())

# For workshops we provide each user with a persistent volume so they
# don't loose their work. This is mounted on /opt/app-root, so we need
# to copy the contents from the image into the persistent volume the
# first time using an init container.

volume_size = os.environ.get('JUPYTERHUB_VOLUME_SIZE')
storage_class = os.environ.get('JUPYTERHUB_STORAGE_CLASS', 'gp2')

if volume_size:
    c.KubeSpawner.pvc_name_template = c.KubeSpawner.pod_name_template
    c.KubeSpawner.storage_pvc_ensure = True
    c.KubeSpawner.storage_capacity = volume_size
    c.KubeSpawner.storage_class = storage_class

    c.KubeSpawner.storage_access_modes.extend(['ReadWriteOnce'])

    c.KubeSpawner.volumes.extend([
        {
            'name': 'data',
            'persistentVolumeClaim': {
                'claimName': c.KubeSpawner.pvc_name_template
            }
        }
    ])

    c.KubeSpawner.volume_mounts.extend([
        {
            'name': 'data',
            'mountPath': '/opt/app-root',
            'subPath': 'workspace'
        }
    ])

    c.KubeSpawner.init_containers.extend([
        {
            'name': 'setup-volume',
            'image': '%s' % c.KubeSpawner.image,
            'command': [
                '/opt/app-root/bin/setup-volume.sh',
                '/opt/app-root',
                '/mnt/workspace'
            ],
            'resources': {
                'limits': {
                    'cpu': '200m',
                    'memory': '32Mi'
                },
                'requests': {
                    'cpu': '80m',
                    'memory': '32Mi'
                }
            },
            'volumeMounts': [
                {
                    'name': 'data',
                    'mountPath': '/mnt'
                }
            ]
        }
    ])

# Make modifications to pod based on user and type of session.

from tornado import gen

@gen.coroutine
def modify_pod_hook(spawner, pod):
    print(f"Called modify_pod_hook(spawner={spawner}, pod={pod})")

    pod.spec.automount_service_account_token = True

    # Grab the OpenShift user access token from the login state.

    auth_state = yield spawner.user.get_auth_state()
    access_token = auth_state['access_token']

    # Set the session access token from the OpenShift login.

    pod.spec.containers[0].env.append(
            dict(name='OPENSHIFT_TOKEN', value=access_token))

    # See if a template for the project name has been specified.
    # Try expanding the name, substituting the username. If the
    # result is different then we use it, not if it is the same
    # which would suggest it isn't unique.

    project = os.environ.get('NOTEBOOK_PROJECT')

    if project:
        name = project.format(username=spawner.user.name)
        if name != project:
            pod.spec.containers[0].env.append(
                    dict(name='PROJECT_NAMESPACE', value=name))

            # Ensure project is created if it doesn't exist.

            pod.spec.containers[0].env.append(
                    dict(name='NOTEBOOK_PROJECT', value=name))

    print(f"Creating {pod}")
    return pod

c.KubeSpawner.modify_pod_hook = modify_pod_hook

# Setup culling of terminal instances if timeout parameter is supplied.

idle_timeout = os.environ.get('JUPYTERHUB_IDLE_TIMEOUT')

if idle_timeout and int(idle_timeout):
    cull_idle_servers_cmd = ['/opt/app-root/bin/cull-idle-servers']

    cull_idle_servers_cmd.append('--timeout=%s' % idle_timeout)

    c.JupyterHub.services.extend([
        {
            'name': 'cull-idle',
            'admin': True,
            'command': cull_idle_servers_cmd,
        }
    ])
