class Kb8Pod

  attr_accessor :name,
                :version,
                :image,
                :replication_controller

  def initialize(yaml_data, replication_controller)
    @replication_controller = replication_controller
    @name = yaml_data['name']
    @image = yaml_data['image']
    @version = yaml_data['image'].split(':').last
  end

  def running?(refresh=false)
    # TODO: get from controller
    @replication_controller.pod_status(@name, refresh)
  end
end
