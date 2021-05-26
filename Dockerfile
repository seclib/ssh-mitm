FROM ubuntu:20.04

# Install openssh-client so we have ssh-keygen.
RUN apt update -qq && DEBIAN_FRONTEND="noninteractive" apt install -y -q openssh-client build-essential autoconf libz-dev git
RUN useradd -m -s /bin/bash ssh-mitm && \
    mkdir -p /home/ssh-mitm/bin /home/ssh-mitm/etc /home/ssh-mitm/log && \
    chown -R ssh-mitm:ssh-mitm /home/ssh-mitm/

COPY openssh-7.5p1 /home/ssh-mitm/openssh-7.5p1/

RUN git clone --depth 1 -b OpenSSL_1_0_2-stable https://github.com/openssl/openssl OpenSSL_1_0_2 && \
    cd OpenSSL_1_0_2 && ./config -v -fstack-protector-all -D_FORTIFY_SOURCE=2 -fPIC no-shared enable-weak-ssl-ciphers zlib && \
    make -j 1 depend && make -j 1 all


RUN cd /home/ssh-mitm/openssh-7.5p1 && \
     autoconf && \
    ./configure --with-sandbox=no --with-privsep-user=ssh-mitm --with-privsep-path=/home/ssh-mitm/empty --with-pid-dir=/home/ssh-mitm --with-lastlog=/home/ssh-mitm --with-ssl-dir=/OpenSSL_1_0_2 && \
    make -j 1

RUN ln -s /home/ssh-mitm/openssh-7.5p1/sshd /home/ssh-mitm/bin/sshd_mitm && \
    ln -s /home/ssh-mitm/openssh-7.5p1/ssh /home/ssh-mitm/bin/ssh && \
    cp /home/ssh-mitm/openssh-7.5p1/sshd_config /home/ssh-mitm/etc/sshd_config && \
    cp /home/ssh-mitm/openssh-7.5p1/ssh_config /home/ssh-mitm/etc/ssh_config

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

USER ssh-mitm
WORKDIR /home/ssh-mitm
RUN mkdir -m 0700 /home/ssh-mitm/empty
RUN mkdir -m 0700 /home/ssh-mitm/.ssh
RUN mkdir -m 0700 /home/ssh-mitm/tmp


EXPOSE 2222/tcp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD /home/ssh-mitm/bin/sshd_mitm -D -e -f /home/ssh-mitm/etc/sshd_config
