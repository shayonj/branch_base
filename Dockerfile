FROM ruby:3.1.4

ARG VERSION

RUN gem install branch_bash -v $VERSION
