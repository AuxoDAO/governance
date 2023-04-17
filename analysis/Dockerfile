FROM ubuntu:22.04

# update packages list
RUN apt-get update

# add pip and solc binaries and add-apt-repository
RUN apt-get install python3-pip software-properties-common curl git jq -y

# install foundry
RUN curl -L https://foundry.paradigm.xyz | bash
RUN /root/.foundry/bin/foundryup

# DL solc by adding to apt repository
RUN add-apt-repository ppa:ethereum/ethereum
RUN apt-get update
RUN apt install solc python3.10-venv -y

# Change the working directory
WORKDIR /work

# adds slither and ability to select solidity compilers
RUN python3 -m venv venv
RUN . venv/bin/activate && \
    pip3 install slither-analyzer solc-select aiohttp openai

# Run the help message on start
ENTRYPOINT ["./analysis/welcome.sh"]

