# rclone remote configuration

The scripts assume an rclone remote named **`wasabi-ferber`** pointing to your Wasabi account and the bucket `ferber-storage`.

Create it via:
```bash
rclone config create wasabi-ferber s3 \
  provider Wasabi \
  access_key_id YOUR_KEY \
  secret_access_key YOUR_SECRET \
  endpoint s3.us-east-1.wasabisys.com
```

Test:
```bash
rclone lsd wasabi-ferber:ferber-storage
```

If your bucket is in a different region, set the correct endpoint.
