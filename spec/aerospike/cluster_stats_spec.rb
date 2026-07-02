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

RSpec.describe Aerospike::ClusterStats do
  def fake_node(name:, connections:, failures:, active:)
    instance_double(
      Aerospike::Node,
      name: name,
      connections: instance_double(Aerospike::ConnectionPool, length: connections),
      failures: instance_double(Aerospike::Atomic, value: failures),
      active?: active
    )
  end

  let(:nodes) do
    [
      fake_node(name: "BB1", connections: 3, failures: 0, active: true),
      fake_node(name: "BB2", connections: 5, failures: 2, active: false)
    ]
  end

  subject(:stats) { described_class.new(nodes) }

  describe '#node_count' do
    it 'returns the number of nodes' do
      expect(stats.node_count).to eq(2)
    end
  end

  describe '#node_names' do
    it 'returns the names of all nodes' do
      expect(stats.node_names).to eq(%w[BB1 BB2])
    end
  end

  describe '#open_connections' do
    it 'sums pooled connections across all nodes' do
      expect(stats.open_connections).to eq(8)
    end

    context 'with no nodes' do
      let(:nodes) { [] }

      it 'returns zero' do
        expect(stats.open_connections).to eq(0)
      end
    end
  end

  describe '#nodes' do
    it 'exposes a NodeStats per node' do
      expect(stats.nodes).to all(be_a(Aerospike::NodeStats))
      expect(stats.nodes.map(&:name)).to eq(%w[BB1 BB2])
      expect(stats.nodes.map(&:available_connections)).to eq([3, 5])
      expect(stats.nodes.map(&:failures)).to eq([0, 2])
      expect(stats.nodes.map(&:active?)).to eq([true, false])
    end
  end

  describe '#to_h' do
    it 'serializes cluster and per-node stats' do
      expect(stats.to_h).to eq(
        node_count: 2,
        node_names: %w[BB1 BB2],
        open_connections: 8,
        nodes: [
          { name: "BB1", available_connections: 3, failures: 0, active: true },
          { name: "BB2", available_connections: 5, failures: 2, active: false }
        ]
      )
    end
  end
end
