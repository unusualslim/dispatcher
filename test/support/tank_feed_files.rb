# Small copies of each tank feed's file layout for tests.
module TankFeedFiles
  KII = <<~CSV.freeze
    Customer ID,Tenant ID,Name,Last Updated Time (UTC),Mapping Site ID,Mapping Tank ID,Sensor Id,Content,Status,Capacity (Gal),Tank Height (In),Water Level (In),Product Temperature (Fahrenheit),Tank Level (Gal),Tank Level (In),Customer,Sensor Owner,Parameter_1,Parameter_4,Parameter_2,Parameter_3,File Post Time (UTC)
    "1","60","DEF 1","11/09/2026 04:35:00 AM","2022","1","#FPS_A","DEF","OK","2198","90","0.26","74.84","1200.50","50","Five Points Service","UnAssigned","-","-","-","-","11/09/2026 05:00:00 AM"
    "1","60","ULSD","11/09/2026 04:08:00 AM","3","6","#PBO_B","DIESEL","WARNING","29786","126","0.93","77.28","9573.22","45","UnAssigned","Perry Brothers Oil","-","-","-","-","11/09/2026 05:00:00 AM"
    "1","60","Coolant","11/08/2026 10:00:17 AM","-","-","#FPS_C","Coolant","OK","6548","126","-","-","-","-","UnAssigned","Five Points Service","-","-","-","-","11/09/2026 05:00:00 AM"
  CSV

  SMARTANK = <<~CSV.freeze
    Report Name:,Inventory 1
    Report Schedule:,1 day (daily )
    Date Range:,11/10/2026 00:00:00 AM - 11/10/2026 00:00:00 AM
    Report Generated On:,11/09/2026 23:54:06 PM

    Comm. Status,Sensor Status,Tank Name,Location Name,City,Inventory Time,"Inventory (Net) (gal)",Product,Capacity (gal),Active,Temp (°F),System Tank ID
    OK,OK,JET THOMSON DEF,MOLLY'S THOMSON,Thomson,11/10/2026 01:53,"1,343.5",Diesel Exhaust Fluid,"2,198",True,61.2,1001
    No Recent Update,OK,z-OLD SCHOOL DEF,School,Sumter,05/01/2024 00:53,227.89,Diesel Exhaust Fluid,850,True,60,1002
    OK,Low Battery Alarm,FARM ULSD,Farm,Vienna,11/10/2026 02:05,648.24,ULTRA LOW DIESEL,1000,False,58,1003
  CSV

  PLANT_0002 = <<~TXT.freeze
    DI Water 61786 Gallons
    Tank 1 1049 Gallons
    P-1 8997 Gallons
    T-8 500 K 381837 Gallons
    Tank 11 0 Gallons
    0 Gallons
  TXT

  SPREADSHEET = <<~CSV.freeze
    tab,site,date,fill_limit,gallons,day_load,night_load
    WRENS,JET WRENS,2026-10-27,1978,1081,,
    WRENS,JET WRENS,2026-10-28,1978,1031,,900
  CSV

  def tank_file(content, name = 'feed.csv')
    dir = Rails.root.join('tmp/test_tank_feeds')
    FileUtils.mkdir_p(dir)
    path = dir.join("#{SecureRandom.hex(4)}-#{name}")
    File.write(path, content)
    path.to_s
  end
end
