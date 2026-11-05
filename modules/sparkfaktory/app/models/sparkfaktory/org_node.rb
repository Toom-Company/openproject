#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Sparkfaktory
  class OrgNode < ApplicationRecord
    self.table_name = "sparkfaktory_org_nodes"

    belongs_to :parent, class_name: "Sparkfaktory::OrgNode", optional: true
    belongs_to :principal
    has_many :children, -> { order(:position, :id) },
             class_name: "Sparkfaktory::OrgNode", foreign_key: :parent_id,
             inverse_of: :parent, dependent: nil

    validates :principal_id, uniqueness: { scope: :parent_id }
    validate :person_appears_once
    validates :title, length: { maximum: 255 }
    validate :principal_is_user_or_group
    validate :parent_is_not_descendant

    before_destroy :hand_children_to_parent

    scope :roots, -> { where(parent_id: nil).order(:position, :id) }

    def self.tree
      nodes = includes(:principal).order(:position, :id).to_a
      by_id = nodes.index_by(&:id)
      by_parent = nodes.group_by(&:parent_id)
      leaders = leaders_by_principal(nodes, by_id)

      nodes.each do |node|
        node.preloaded_children = by_parent.fetch(node.id, [])
        node.leaders = leaders.fetch(node.principal_id, [])
      end
      by_parent.fetch(nil, [])
    end

    # A team may hang below several leaders; every one of its nodes lists all of them.
    def self.leaders_by_principal(nodes, by_id)
      nodes.select(&:group?).group_by(&:principal_id).transform_values do |team_nodes|
        team_nodes.filter_map { by_id[it.parent_id]&.principal }.grep(User).uniq
      end
    end

    attr_writer :preloaded_children, :leaders

    def leaders
      @leaders || []
    end

    def preloaded_children
      @preloaded_children || children.to_a
    end

    def group? = principal.is_a?(Group)

    def descendant_ids
      ids = []
      frontier = [id]
      while frontier.any?
        frontier = self.class.where(parent_id: frontier).pluck(:id) - ids
        ids.concat(frontier)
      end
      ids
    end

    private

    def person_appears_once
      return unless principal.is_a?(User)
      return unless self.class.where(principal_id:).where.not(id:).exists?

      errors.add(:principal_id, :taken)
    end

    def principal_is_user_or_group
      return if principal.is_a?(User) || principal.is_a?(Group)

      errors.add(:principal_id, :invalid)
    end

    def parent_is_not_descendant
      return if parent_id.nil? || new_record?
      return unless parent_id == id || descendant_ids.include?(parent_id)

      errors.add(:parent_id, :invalid)
    end

    def hand_children_to_parent
      already_there = self.class.where(parent_id:).where.not(id:).select(:principal_id)
      self.class.where(parent_id: id, principal_id: already_there).delete_all
      self.class.where(parent_id: id).update_all(parent_id:)
    end
  end
end
