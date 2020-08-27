JUPYTERHUB_NAMESPACE="${JUPYTERHUB_NAMESPACE:-default}"
APPLICATION_NAME="${APPLICATION_NAME:-default}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-${APPLICATION_NAME}-hub}"

if [ x"$CONFIGURATION_TYPE" != x"" ]; then
    if [ -f /opt/app-root/etc/jupyterhub_config-$CONFIGURATION_TYPE.sh ]; then
        . /opt/app-root/etc/jupyterhub_config-$CONFIGURATION_TYPE.sh
    fi
fi

if [ -f /opt/app-root/src/.jupyter/jupyterhub_config.sh ]; then
    . /opt/app-root/src/.jupyter/jupyterhub_config.sh
fi

if [ -f /opt/app-root/configs/jupyterhub_config.sh ]; then
    . /opt/app-root/configs/jupyterhub_config.sh
fi
