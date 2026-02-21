# syntax=docker/dockerfile:1

# Build stage
FROM ruby:3.4-slim AS builder

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_RETRY=3

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Runtime stage
FROM ruby:3.4-slim

RUN groupadd --system --gid 1000 app && \
    useradd --system --uid 1000 --gid app --create-home app

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

WORKDIR /app

COPY --from=builder --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /app /app

USER app:app

EXPOSE 9292

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ruby -e "require 'net/http'; Net::HTTP.get_response(URI('http://localhost:9292/')).is_a?(Net::HTTPSuccess) || exit(1)"

CMD ["bundle", "exec", "falcon", "host"]
