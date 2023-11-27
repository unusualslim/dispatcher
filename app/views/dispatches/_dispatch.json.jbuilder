json.extract! dispatch, :id, :driver_id, :origin, :info, :dispatch_date, :status, :notes, :created_at, :updated_at
json.url dispatch_url(dispatch, format: :json)
