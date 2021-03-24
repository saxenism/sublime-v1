FROM node:10.22.0-jessie
RUN cd ~ && mkdir app
WORKDIR /home/app

RUN npm i -g truffle
RUN npm i -g ganache-cli
RUN npm install @0x/sol-compiler --g
RUN npm i -g sol-merger
RUN npm install truffle-flattener -g

COPY package.json /home/app/package.json
COPY package-lock.json /home/app/package-lock.json

# RUN npm install
# RUN npm audit fix

COPY . /home/app

CMD [ "ganache-cli","-a","100", "-l","12000000","-f","https://eth-mainnet.alchemyapi.io/v2/snGskhAXMQaRLnJaxbcfOL7U5_bSZl_Y"]