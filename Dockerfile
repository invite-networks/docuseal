FROM ruby:4.0.5-alpine AS download

WORKDIR /fonts

# Every downloaded artifact is pinned to an immutable ref and verified against
# a SHA-256 checksum before it is copied into the runtime image.
RUN apk --no-cache add wget unzip && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Regular.ttf && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Bold.ttf && \
    wget https://github.com/impallari/DancingScript/raw/09b7abf420f296894dc6c878e7b0da4f9f8d27a6/fonts/DancingScript-Regular.otf && \
    wget https://raw.githubusercontent.com/impallari/DancingScript/09b7abf420f296894dc6c878e7b0da4f9f8d27a6/OFL.txt && \
    wget https://raw.githubusercontent.com/notofonts/noto-fonts/ffebf8c1ee449e544955a7e813c54f9b73848eac/LICENSE && \
    wget -O /model.onnx "https://github.com/docusealco/fields-detection/releases/download/2.0.0/model_704_int8.onnx" && \
    wget -O pdfium-linux.zip "https://github.com/docusealco/pdfium-binaries/releases/download/20260813/pdfium-musl-$(uname -m).zip" && \
    printf '%s\n' \
      "2f2cee5fbb2403df352ca2005247f6c4faa70f3086ebd31b6c62308b5f2f9865  GoNotoKurrent-Regular.ttf" \
      "6f5ab7b16acedeac76625f75159d9d303be85b291d47376760a1c9f87802853e  GoNotoKurrent-Bold.ttf" \
      "d71f864af9c13eeb740230fd67309c2390a902dba2326ae06f2275ca52663c6a  DancingScript-Regular.otf" \
      "6f090277c00af96651ce6dbcc38ff1591047a3bffef486e80b6a32e8276a8201  OFL.txt" \
      "0dab92d0544f7b233403f14b84a663bdbfa746982eda629e7f4f9ffe1b036feb  LICENSE" \
      "a0a92ef7f50b6e5c707b7da9c59977bc7c9e9d8f85542bd75169c693f5efa4da  /model.onnx" | sha256sum -c - && \
    case "$(uname -m)" in \
      x86_64)  echo "c5c7dde243ecb66ab0819c8193515ef38ad53549fe260f3c2dfd93ea56eda2e7  pdfium-linux.zip" ;; \
      aarch64) echo "64c4483449b1b4dccc696ad0c5c96e0b7f74dcc57b4f23c676b7a70671b0bbb5  pdfium-linux.zip" ;; \
    esac | sha256sum -c - && \
    mkdir -p /pdfium-linux && \
    unzip -q pdfium-linux.zip -d /pdfium-linux

FROM ruby:4.0.5-alpine AS webpack

ENV RAILS_ENV=production
ENV NODE_ENV=production

WORKDIR /app

# Keep the build-stage gem in lockstep with Gemfile and package.json.
RUN apk add --no-cache nodejs yarn git build-base && \
    gem install shakapacker -v 10.3.2

COPY ./package.json ./yarn.lock ./

RUN yarn install --frozen-lockfile --network-timeout 1000000

COPY ./bin/shakapacker ./bin/shakapacker
COPY ./config/webpack ./config/webpack
COPY ./config/shakapacker.yml ./config/shakapacker.yml
COPY ./postcss.config.js ./postcss.config.js
COPY ./app/javascript ./app/javascript
COPY ./app/views ./app/views

RUN echo "gem 'shakapacker', '10.3.2'" > Gemfile && ./bin/shakapacker

FROM ruby:4.0.5-alpine AS app

ENV RAILS_ENV=production
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}

WORKDIR /app

RUN apk add --no-cache libpq vips redis onnxruntime leptonica && \
    rm -f /usr/bin/onnx_test_runner /usr/bin/onnxruntime_test

# Fixed non-root identity. The data directory bind mount must be owned by
# 1001:1001 on the host (see README).
RUN addgroup -g 1001 docuseal && adduser -u 1001 -G docuseal -s /bin/sh -D -h /home/docuseal docuseal

COPY --chown=docuseal:docuseal ./Gemfile ./Gemfile.lock ./

# The Gemfile pins json, net-imap, and resolv above the interpreter-bundled
# versions with known CVEs. Drop the stale default gemspecs so only the patched
# gems from the bundle can be activated and the image scans clean.
RUN apk add --no-cache build-base git libpq-dev yaml-dev && bundle install && \
    for gem in json net-imap resolv; do rm -rf /usr/local/lib/ruby/gems/*/specifications/default/${gem}-[0-9]*.gemspec /usr/local/lib/ruby/gems/*/specifications/${gem}-[0-9]*.gemspec /usr/local/lib/ruby/gems/*/gems/${gem}-[0-9]*; done && apk del --no-cache build-base git libpq-dev yaml-dev && rm -rf ~/.bundle /usr/local/bundle/cache && ruby -e "puts Dir['/usr/local/bundle/**/{spec,rdoc,resources/shared,resources/collation,resources/locales,resources/unicode_data/properties}'] + Dir['/usr/local/bundle/gems/*/{test,tests,examples,sample,misc,doc,docs}'] + Dir['/usr/local/bundle/gems/*/ext/**/*.{c,h,o,S}']" | xargs rm -rf && ln -sf /usr/lib/libonnxruntime.so.1 $(ruby -e "print Dir[Gem::Specification.find_by_name('onnxruntime').gem_dir + '/vendor/*.so'].first")

ARG INSTALL_TEST_BROWSER=false
RUN if [ "${INSTALL_TEST_BROWSER}" = "true" ]; then apk add --no-cache chromium; fi

COPY --chown=docuseal:docuseal ./bin ./bin
COPY --chown=docuseal:docuseal ./app ./app
COPY --chown=docuseal:docuseal ./config ./config
COPY --chown=docuseal:docuseal ./db/migrate ./db/migrate
COPY --chown=docuseal:docuseal ./log ./log
COPY --chown=docuseal:docuseal ./lib ./lib
COPY --chown=docuseal:docuseal ./public ./public
COPY --chown=docuseal:docuseal ./tmp ./tmp
COPY --chown=docuseal:docuseal LICENSE LICENSE_ADDITIONAL_TERMS README.md Rakefile config.ru .version ./
COPY --chown=docuseal:docuseal .version ./public/version

COPY --chown=docuseal:docuseal --from=download /fonts/GoNotoKurrent-Regular.ttf /fonts/GoNotoKurrent-Bold.ttf /fonts/DancingScript-Regular.otf /fonts/OFL.txt /fonts/LICENSE /fonts/
COPY --from=download /pdfium-linux/lib/libpdfium.so /usr/lib/libpdfium.so
COPY --from=download /pdfium-linux/licenses/ /usr/lib/libpdfium-licenses/
COPY --chown=docuseal:docuseal --from=download /model.onnx /app/tmp/model.onnx
COPY --chown=docuseal:docuseal --from=webpack /app/public/packs ./public/packs

RUN if [ "${INSTALL_TEST_BROWSER}" = "true" ]; then cp -R ./public/packs ./public/packs-test; fi

RUN mkdir -p /app/public/fonts && ln -s /fonts/DancingScript-Regular.otf /fonts/GoNotoKurrent-Regular.ttf /app/public/fonts/ && \
    mkdir -p /usr/share/fonts/noto && ln -s /fonts/GoNotoKurrent-Regular.ttf /usr/share/fonts/noto/ && ln -s /fonts/GoNotoKurrent-Bold.ttf /usr/share/fonts/noto/ && fc-cache -f && \
    bundle exec bootsnap precompile -j 1 --gemfile app/ lib/ && \
    mkdir -p /data/docuseal && \
    chown -R docuseal:docuseal /app/tmp /app/log /app/public /data/docuseal /home/docuseal

USER docuseal

WORKDIR /data/docuseal
ENV HOME=/home/docuseal
ENV WORKDIR=/data/docuseal
ENV VIPS_MAX_COORD=17000
ENV VIPS_BLOCK_UNTRUSTED=1

EXPOSE 3000
CMD ["/app/bin/bundle", "exec", "puma", "-C", "/app/config/puma.rb", "--dir", "/app"]
