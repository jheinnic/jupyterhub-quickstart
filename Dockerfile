FROM registry.redhat.io/rhscl/python-36-rhel7@sha256:d8881affb7666e9f1e5b718b27db89c41ab3b8ebeb12510772bf221ee74895db

LABEL io.k8s.display-name="JupyterHub" \
      io.k8s.description="JupyterHub." \
      io.openshift.tags="builder,python,jupyterhub" \
      io.openshift.s2i.scripts-url="image:///opt/app-root/builder"

USER root

COPY builder /opt/app-root/builder
COPY jupyterhub_config.py /opt/app-root/etc/
COPY jupyterhub_config.sh /opt/app-root/etc/
COPY jupyterhub_config-workspace.py /opt/app-root/etc/
COPY jupyterhub_config-workspace.sh /opt/app-root/etc/
COPY scripts/* /opt/app-root/bin/
COPY start-jupyterhub.sh /opt/app-root/bin

# Ensure we are using the latest pip and wheel packages.
# Install python and npm packages needed for running JupyterHub.
#
# Scripts used to be kept in /opt/app-root/scripts but are now in the
# directory /opt/app-root/bin. Create a symlink for wait-for-database
# for now until any templates running script from old location are
# purged.
# 
# Ensure passwd/group file intercept happens for any shell environment.
#
# Create additional directories.
#
# Fixup permissions on directories and files.
RUN pip install -U pip setuptools wheel && \
    pip install -r /tmp/src/requirements.txt && \
    echo " -----> Installing npm packages." && \
    npm install -g configurable-http-proxy && \
    mkdir -p /opt/app-root/scripts && \
    ln -s /opt/app-root/bin/wait-for-database /opt/app-root/scripts/wait-for-database && \
    echo "source /opt/app-root/etc/generate_container_user" >> /opt/app-root/etc/scl_enable && \
    echo " -----> Creating additional directories." && \
    mkdir -p /opt/app-root/data && \
    chown -R 1001 /opt/app-root/bin /opt/app-root/etc /opt/app-root/builder && \
    chgrp -R 0 /opt/app-root/bin /opt/app-root/etc /opt/app-root/builder && \
    chmod -R g+w /opt/app-root/bin /opt/app-root/etc /opt/app-root/builder

USER 1001

ENV NPM_CONFIG_PREFIX=/opt/app-root \
    PYTHONPATH=/opt/app-root/src

# No need to specify CMD or ENTRYPOINT as we wish to inherit those choices from S2I.
