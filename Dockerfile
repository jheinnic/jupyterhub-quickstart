FROM registry.redhat.io/rhscl/python-36-rhel7:1-76.1596049344

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
COPY requirements.txt /opt/app-root/src

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
RUN source /opt/app-root/etc/scl_enable && \
    pip install -U pip setuptools wheel && \
    pip install -r /opt/app-root/src/requirements.txt && \
    echo " -----> Installing npm packages." && \
    npm install -g configurable-http-proxy && \
    mkdir -p /opt/app-root/scripts && \
    ln -s /opt/app-root/bin/wait-for-database /opt/app-root/scripts/wait-for-database && \
    echo "source /opt/app-root/etc/generate_container_user" >> /opt/app-root/etc/scl_enable && \
    echo " -----> Creating additional directories." && \
    mkdir -p /opt/app-root/data && \
    # chown -R 1001 /opt/app-root/bin /opt/app-root/etc /opt/app-root/builder /opt/app-root/src/requirements.txt && \
    # chgrp -R 0 /opt/app-root/bin /opt/app-root/etc /opt/app-root/builder && \
    # chmod -R g+w /opt/app-root/bin /opt/app-root/etc /opt/app-root/builder && \
    rm /opt/app-root/src/requirements.txt && \
    chown -R 1001 /opt/app-root/[bdersR]* && \
    chgrp -R 0 /opt/app-root/[bdersR]* && \
    chmod -R g+w /opt/app-root/[bdersR]* && \
    fix-permissions /opt/app-root 

USER 1001

ENV NPM_CONFIG_PREFIX=/opt/app-root \
    PYTHONPATH=/opt/app-root/src

# Declaring this CMD is not necessary, but does allow the S2i builder to be run
# without having been used to build a source directory with default overrides,
# in which case it simply runs JupyterHub as though the Assembly step had been
# run against an empty source repository.  Without this, we would have to
# actually perform a no-op assembly run against and empty source repository and
# use the resulting image to access that same behavior.
CMD [ "/opt/app-root/builder/run" ]
