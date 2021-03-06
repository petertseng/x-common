require 'json'
require_relative '../../verify'

module Pov
  # This is just a verification script and not real code or an Exercism submission,
  # so I'm OK with dirtying all Hashees.
  refine Hash do
    def label
      self['label']
    end

    def children
      self['children'] || []
    end

    def as_child_of(new_parent)
      new_parent.merge('children' => [without_child(new_parent.label)] + new_parent.children)
    end

    def without_child(victim)
      merge('children' => children.reject { |c| c.label == victim })
    end

    def reroot(new_root)
      reroot_cps(new_root, &:itself)
    end

    def reroot_cps(new_root)
      return yield self if label == new_root

      children.map { |c|
        c.reroot_cps(new_root) { |x| (yield self).as_child_of(x) }
      }.find(&:itself)
    end

    def edges
      children.map { |c| [label, c.label] } + children.flat_map { |c| c.edges }
    end

    def path(from:, to:)
      (rerooted = reroot(from)) && rerooted.path_to(to)
    end

    def path_to(to)
      return [label] if label == to
      (child_path = children.map { |c| c.path_to(to) }.find(&:itself)) && [label] + child_path
    end
  end
end

using Pov

def equal_on(got, want, f)
  (got && f[got]) == (want && f[want])
end

json = JSON.parse(File.read(File.join(__dir__, 'canonical-data.json')))

raise "There should be exactly two cases, not #{json['cases'].size}" if json['cases'].size != 2

multi_verify(json['cases'][0]['cases'], accept: ->(c, ans) {
  [
    ->(x) { x.label },
    ->(x) { x.edges.sort },
  ].all? { |f|
    equal_on(ans, c['expected'], f)
  }
}, property: 'fromPov', implementations: [
  {
    name: 'cps',
    f: ->(i, _) {
      tree = i['tree'].freeze
      tree.reroot(i['from'])
    }
  },
  {
    name: 'find path then reverse links',
    f: ->(i, _) {
      tree = i['tree'].freeze
      path = tree.path(from: tree.label, to: i['from'])
      path&.drop(1)&.each { |child_label|
        tree = tree.as_child_of(tree.children.find { |c| c.label == child_label })
      } && tree
    }
  },
])

multi_verify(json['cases'][1]['cases'], property: 'pathTo', implementations: [
  {
    name: 'correct',
    f: ->(i, _) {
      tree = i['tree'].freeze
      tree.path(from: i['from'], to: i['to'])
    },
  },
  {
    # https://github.com/exercism/problem-specifications/pull/1227
    name: 'always root',
    should_fail: true,
    f: ->(i, _) {
      tree = i['tree'].freeze
      return nil unless (first_half = tree.path(from: tree.label, to: i['from']))
      return nil unless (second_half = tree.path(from: tree.label, to: i['to']))
      # drop 1 to remove the duplicate root
      first_half.reverse + second_half.drop(1)
    },
  },
])
