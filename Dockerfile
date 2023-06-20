FROM mhart/alpine-node:16
WORKDIR /usr/src/app
COPY . /usr/src/app/

RUN yarn

CMD ["yarn", "chain"]