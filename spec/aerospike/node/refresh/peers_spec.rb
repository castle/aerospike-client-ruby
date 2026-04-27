# frozen_string_literal: true

# Copyright 2026 Aerospike, Inc.
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

RSpec.describe Aerospike::Node::Refresh::Peers do
  subject(:call!) { described_class.call(node, peers) }

  let(:node) { double('node') }
  let(:cluster) { double('cluster') }
  let(:tend_connection) { double('tend_connection') }
  let(:peers) { ::Aerospike::Peers.new }
  let(:peers_generation) { ::Aerospike::Node::Generation.new }
  let(:peers_count) { ::Aerospike::Atomic.new(0) }

  let(:peer_node_name) { 'BB92118BAB14E12' }
  let(:peer_host) { ::Aerospike::Host.new('172.31.73.252', 3000) }
  let(:peer) do
    ::Aerospike::Peer.new.tap do |p|
      p.node_name = peer_node_name
      p.hosts = [peer_host]
    end
  end

  let(:fetch_collection) do
    instance_double(
      ::Aerospike::Peers::Parse::Object,
      generation: 1,
      peers: [peer]
    )
  end

  before do
    allow(node).to receive(:cluster).and_return(cluster)
    allow(node).to receive(:tend_connection).and_return(tend_connection)
    allow(node).to receive(:peers_count).and_return(peers_count)
    allow(node).to receive(:peers_generation).and_return(peers_generation)
    allow(node).to receive(:failures).and_return(::Aerospike::Atomic.new(0))
    allow(node).to receive(:active?).and_return(true)
    allow(node).to receive(:name).and_return('node-self')

    allow(cluster).to receive(:connection_timeout).and_return(1000)
    allow(cluster).to receive(:cluster_name).and_return('test')
    allow(cluster).to receive(:tls_options).and_return({})
    allow(cluster).to receive(:find_node_by_name).and_return(nil)
    allow(cluster).to receive(:create_node)

    allow(::Aerospike::Peers::Fetch).to receive(:call).and_return(fetch_collection)
    allow(::Aerospike::Cluster::FindNode).to receive(:call).and_return(nil)
    allow(::Aerospike::Node::Refresh::Failed).to receive(:call)
    allow(::Aerospike.logger).to receive(:warn)
  end

  context 'happy path: validator returns matching name and non-empty aliases' do
    let(:new_node) { instance_double(::Aerospike::Node) }
    let(:nv) do
      instance_double(
        ::Aerospike::NodeValidator,
        name: peer_node_name,
        aliases: [peer_host]
      )
    end

    before do
      allow(::Aerospike::NodeValidator).to receive(:new).and_return(nv)
      allow(cluster).to receive(:create_node).with(nv).and_return(new_node)
      call!
    end

    it 'creates the node and stores it in peers under the validator name' do
      expect(cluster).to have_received(:create_node).with(nv)
      expect(peers.nodes[peer_node_name]).to eq(new_node)
      expect(peers_generation.changed?).to be(true)
    end
  end

  context 'guard fires when validator name is nil' do
    let(:nv) do
      instance_double(::Aerospike::NodeValidator, name: nil, aliases: [])
    end

    before do
      allow(::Aerospike::NodeValidator).to receive(:new).and_return(nv)
      call!
    end

    it 'skips create_node, leaves peers.nodes empty, and warns' do
      expect(cluster).not_to have_received(:create_node)
      expect(peers.nodes).to be_empty
      expect(::Aerospike.logger).to have_received(:warn).with(/Skipping peer.*name=nil/)
    end
  end

  context 'guard fires when name matches but aliases is empty (path 4)' do
    let(:nv) do
      instance_double(::Aerospike::NodeValidator, name: peer_node_name, aliases: [])
    end

    before do
      allow(::Aerospike::NodeValidator).to receive(:new).and_return(nv)
      call!
    end

    it 'still skips create_node — mismatch check below cannot catch this' do
      expect(cluster).not_to have_received(:create_node)
      expect(peers.nodes).to be_empty
      expect(::Aerospike.logger).to have_received(:warn).with(/aliases=0/)
    end
  end

  context 'continues iterating peer.hosts after a guarded skip (next, not break)' do
    let(:peer_host_b) { ::Aerospike::Host.new('172.31.73.253', 3000) }
    let(:peer) do
      ::Aerospike::Peer.new.tap do |p|
        p.node_name = peer_node_name
        p.hosts = [peer_host, peer_host_b]
      end
    end

    let(:bad_nv) do
      instance_double(::Aerospike::NodeValidator, name: nil, aliases: [])
    end
    let(:good_nv) do
      instance_double(::Aerospike::NodeValidator, name: peer_node_name, aliases: [peer_host_b])
    end
    let(:new_node) { instance_double(::Aerospike::Node) }

    before do
      allow(::Aerospike::NodeValidator).to receive(:new) do |_, host, *|
        host == peer_host ? bad_nv : good_nv
      end
      allow(cluster).to receive(:create_node).with(good_nv).and_return(new_node)
      call!
    end

    it 'validates the second host and stores its node' do
      expect(cluster).to have_received(:create_node).with(good_nv)
      expect(peers.nodes[peer_node_name]).to eq(new_node)
    end
  end
end
