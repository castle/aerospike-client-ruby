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
  # Contract for an object that receives periodic cluster metrics.
  #
  # Register an implementation via {ClientPolicy#metrics_listener} (or the
  # +:metrics_listener+ policy option). Once registered, {#report} is invoked
  # from the tend thread once per tend interval with a fresh {ClusterStats}
  # snapshot — including on cycles where the node set did not change — so that
  # gauges (e.g. node count) stay alive in the downstream metrics system.
  #
  # Implementing this module is optional; any object responding to
  # +report(cluster_stats)+ is accepted (duck typing). It exists to document
  # the contract.
  #
  # Exceptions raised by {#report} are caught and logged by the tend thread;
  # they do not interrupt tending. Keep implementations fast and non-blocking,
  # as {#report} runs inline on the tend thread.
  module MetricsListener
    # @param cluster_stats [Aerospike::ClusterStats] snapshot for this cycle
    # @return [void]
    def report(cluster_stats)
      raise NotImplementedError, "#{self.class} must implement #report(cluster_stats)"
    end
  end
end
