KUBERNETES_SERVER_URL="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"
OAUTH_METADATA_URL="$KUBERNETES_SERVER_URL/.well-known/oauth-authorization-server"
OAUTH_ISSUER_ADDRESS=`curl -ks $OAUTH_METADATA_URL | grep '"issuer":' | sed -e 's%.*https://%https://%' -e 's%",%%'`

export OPENSHIFT_REST_API_URL=$KUBERNETES_SERVER_URL
export OPENSHIFT_AUTH_API_URL=$OAUTH_ISSUER_ADDRESS

# export OAUTH_CLIENT_ID="system:serviceaccount:${JUPYTERHUB_NAMESPACE}:${APPLICATION_NAME}-hub"
# export OAUTH_CLIENT_SECRET=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`

export NOTEBOOK_PROJECT="${NOTEBOOK_PROJECT:-${JUPYTERHUB_PROJECT}}"
