# frozen_string_literal: true

# Copyright 2014-2020 Aerospike, Inc.
#
# Portions may be licensed to Aerospike, Inc. under one or more contributor
# license agreements.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

module Aerospike
  # Immutable snapshot of per-node statistics, captured during a tend cycle.
  #
  # @see Aerospike::ClusterStats
  class NodeStats
    # Node name as reported by the server, e.g. "BB9ED567E640112".
    attr_reader :name

    # Number of idle connections currently pooled for this node.
    attr_reader :available_connections

    # Number of consecutive tend failures recorded for this node.
    attr_reader :failures

    def initialize(node)
      @name = node.name
      @available_connections = node.connections.length
      @failures = node.failures.value
      @active = node.active?
    end

    # Whether the node is currently considered active by the client.
    def active?
      @active
    end

    def to_h
      {
        name: name,
        available_connections: available_connections,
        failures: failures,
        active: active?
      }
    end
  end

  # Immutable snapshot of cluster-wide statistics, passed to a
  # {MetricsListener#report} implementation once per tend interval.
  #
  # @example Reporting node count to Datadog (dogstatsd-ruby)
  #   class DatadogReporter
  #     def initialize(statsd); @statsd = statsd; end
  #
  #     def report(stats)
  #       @statsd.gauge("aerospike.cluster.nodes", stats.node_count)
  #       @statsd.gauge("aerospike.cluster.open_connections", stats.open_connections)
  #       stats.nodes.each do |node|
  #         tags = ["node:#{node.name}"]
  #         @statsd.gauge("aerospike.node.available_connections", node.available_connections, tags: tags)
  #         @statsd.gauge("aerospike.node.failures", node.failures, tags: tags)
  #       end
  #     end
  #   end
  #
  #   client = Aerospike::Client.new(hosts, policy: { metrics_listener: DatadogReporter.new(Datadog::Statsd.new) })
  class ClusterStats
    # Array of {NodeStats}, one per node currently known to the cluster.
    attr_reader :nodes

    def initialize(nodes)
      @nodes = nodes.map { |node| NodeStats.new(node) }
    end

    # Number of nodes currently known to the cluster.
    def node_count
      @nodes.size
    end

    # Names of all nodes currently known to the cluster.
    def node_names
      @nodes.map(&:name)
    end

    # Total number of idle pooled connections across all nodes.
    def open_connections
      @nodes.reduce(0) { |sum, node| sum + node.available_connections }
    end

    def to_h
      {
        node_count: node_count,
        node_names: node_names,
        open_connections: open_connections,
        nodes: @nodes.map(&:to_h)
      }
    end
  end
end
