require "placeos-driver"

class Broken < PlaceOS::Driver
  descriptive_name "Broken"
  generic_name :Helper

  def broken_method
    # This should not compile
    "1" + 1
  end
end
