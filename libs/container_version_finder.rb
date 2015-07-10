class ContainerVersionFinder

  attr_accessor :versions_by_image_name,
                :files_by_image_name

  # Object to get container versions from glob path:
  # E.g.
  # ../artefacts/*_container_version
  # allow access by file name sans the glob portion...
  def initialize(glob_path)

    base_glob_name = File.basename(glob_path)
    regexp_find = base_glob_name.gsub(/\*/, '(.*)')

    @versions_by_image_name = {}

    Dir[glob_path].each do | file_name |

      # Get the image name from the file part of the glob path:
      # e.g. given lev_ora_container_version
      # get lev_ora from ../artefacts/*_container_version
      image_name = /#{regexp_find}/.match(File.basename(file_name)).to_a()[0]

      puts "File:#{file_name} => #{image_name}"
      @files_by_image_name[image_name] = file_name
    end
  end

  # Defer access until we know the file should defo. exist with version string
  def get_version(image, default_version)
    version = default_version
    if @versions_by_image_name[image]
      version = @versions_by_image_name[image]
    else
      if @files_by_image_name[image]
        version = File.read(@files_by_image_name[image])
      end
    end
    version
  end
end
