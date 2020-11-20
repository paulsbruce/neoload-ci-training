FROM python:3.7-alpine

# add the Jenkins user to container for file permissions to pip install neoload
RUN apk add -q git shadow sudo
RUN addgroup -g 993 -S jenkins && adduser --uid 997 -S jenkins -G jenkins && passwd -d jenkins
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/jenkins && chmod 0440 /etc/sudoers.d/jenkins

# add tools to help parse output of CLI (nice to have)
RUN apk add -q jq py3-lxml

# pre-install NeoLoad CLI
WORKDIR /opt/neoload
RUN git clone --single-branch --branch topic-report-command https://github.com/Neotys-Labs/neoload-cli.git
RUN cd neoload-cli && python3 -m pip install -q .

# or run official version that doesn't yet include advanced reporting
#RUN pip install -q neoload

# switch back to proper non-root user
USER jenkins
