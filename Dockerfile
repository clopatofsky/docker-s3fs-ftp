FROM centos:7

ARG USER_ID=14
ARG GROUP_ID=50

ENV S3_FUSE_VERSION 1.85

MAINTAINER Fer Uria <fauria@gmail.com>
LABEL Description="vsftpd Docker image based on Centos 7. Supports passive mode and virtual users." \
	License="Apache License 2.0" \
	Usage="docker run -d -p [HOST PORT NUMBER]:21 -v [HOST FTP HOME]:/home/vsftpd fauria/vsftpd" \
	Version="1.0"

RUN yum -y update && yum clean all
RUN yum install -y \
	vsftpd \
	db4-utils \
	automake \
	make \
    openssl-devel \
    git \
    gcc \
    libstdc++-devel \
    gcc-c++ \
    fuse \
    fuse-devel \
    curl-devel \
    libxml2-devel \
	db4 && yum clean all

RUN usermod -u ${USER_ID} ftp
RUN groupmod -g ${GROUP_ID} ftp

ENV FTP_USER **String**
ENV FTP_PASS **Random**
ENV PASV_ADDRESS **IPv4**
ENV PASV_ADDR_RESOLVE NO
ENV PASV_ENABLE YES
ENV PASV_MIN_PORT 21100
ENV PASV_MAX_PORT 21110
ENV LOG_STDOUT **Boolean**
ENV FILE_OPEN_MODE 0666
ENV LOCAL_UMASK 077

COPY vsftpd.conf /etc/vsftpd/
COPY vsftpd_virtual /etc/pam.d/
COPY run-vsftpd.sh /usr/sbin/

RUN chmod +x /usr/sbin/run-vsftpd.sh
RUN mkdir -p /home/vsftpd/
RUN chown -R ftp:ftp /home/vsftpd/

VOLUME /home/vsftpd
VOLUME /var/log/vsftpd

EXPOSE 20 21


RUN mkdir -p /home/sources
WORKDIR /home/sources

RUN git clone https://github.com/s3fs-fuse/s3fs-fuse.git /home/sources/s3fs

WORKDIR /home/sources/s3fs

RUN ./autogen.sh
RUN ./configure

RUN make
RUN make install

CMD ["/usr/sbin/run-vsftpd.sh"]

