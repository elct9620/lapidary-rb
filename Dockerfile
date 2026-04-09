# syntax=docker/dockerfile:1

# Build stage
FROM ruby:4.0 AS builder

WORKDIR /app

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_RETRY=3

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.1 && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Runtime stage
FROM ruby:4.0-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1000 app && \
    useradd --system --uid 1000 --gid app --create-home app

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

WORKDIR /app

COPY --from=builder --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /app /app

RUN mkdir -p /app/data && chown app:app /app/data

ENV RACK_ENV=production

USER app:app

VOLUME /app/data

EXPOSE 9292

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:9292/health || exit 1

CMD ["bundle", "exec", "falcon", "host"]
