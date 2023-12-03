FROM ruby:3.1.4

ARG VERSION

RUN apt-get update && apt-get install libgit2-dev cmake pkg-config -y
RUN gem install branch_base -v $VERSION
