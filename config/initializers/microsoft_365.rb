# frozen_string_literal: true

require Rails.root.join('lib/microsoft_365/config')
require Rails.root.join('lib/microsoft_365/graph_mail_delivery')

ActionMailer::Base.add_delivery_method :microsoft_graph, Microsoft365::GraphMailDelivery
