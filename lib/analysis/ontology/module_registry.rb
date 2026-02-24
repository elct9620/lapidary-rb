# auto_register: false
# frozen_string_literal: true

module Analysis
  module Ontology
    # Stateless registry of valid CoreModule and Stdlib names from the curated ontology.
    module ModuleRegistry
      CORE_MODULES = Set.new(%w[
                               Array BasicObject Binding Class Comparable Complex Dir Encoding
                               Enumerable Enumerator Errno Exception FalseClass Fiber File Float
                               GC Hash IO Integer Kernel Marshal MatchData Math Method Module
                               NilClass Numeric Object ObjectSpace Proc Process Ractor Random
                               Range Rational Regexp Signal String Struct Symbol Thread Time
                               TrueClass UnboundMethod
                             ]).freeze

      STDLIBS = Set.new(%w[
                          abbrev base64 benchmark bigdecimal bundler cgi csv date delegate
                          digest drb english erb etc fcntl fiddle fileutils find forwardable
                          getoptlong io/console io/nonblock io/wait ipaddr irb json logger
                          monitor mutex_m net/ftp net/http net/imap net/pop net/smtp nkf
                          objspace observer open-uri open3 openssl optparse ostruct pathname
                          pp prettyprint pstore psych racc rdoc readline reline resolv ripper
                          ruby2_keywords securerandom set shellwords singleton socket stringio
                          strscan syntax_suggest syslog tempfile time timeout tmpdir tsort un
                          uri weakref yaml zlib
                        ]).freeze

      def self.core_module?(name)
        CORE_MODULES.include?(name)
      end

      def self.stdlib?(name)
        STDLIBS.include?(name)
      end

      def self.valid?(name)
        core_module?(name) || stdlib?(name)
      end
    end
  end
end
