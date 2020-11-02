FROM python:3.7-alpine
# add the Jenkins user to container for file permissions and Docker socket chmod
RUN apk add -q git shadow sudo jq curl
RUN addgroup -g 993 -S jenkins && adduser --uid 997 -S jenkins -G jenkins && passwd -d jenkins
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/jenkins && chmod 0440 /etc/sudoers.d/jenkins
# pre-install NeoLoad CLI
WORKDIR /opt/neoload
RUN git clone --single-branch --branch topic-docker-command https://github.com/Neotys-Labs/neoload-cli.git
RUN cd neoload-cli && python3 -m pip install -q .
#RUN pip install -q neoload
USER jenkins
