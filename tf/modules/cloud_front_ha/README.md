# Cloudfront for High Availability

This module is just to allow quickly switching from one s3 bucket to another.

Cloudfront is one of the global services, so it can be used for HA. The other is Route 53.

## Automatic Failover Design and disadvantages
Cloudfront can redirect traffic to the other region on every error. This means it would be an
active-active arrangement.

Also, if an error was transient, we could end up with flapping, rapid switching back and forth between
the two regions.

## Manual Failover
If the failover process involves changing a variable and running a plan/apply, then there is
a longer switch over, but the infrastructure in the failover region will always be ready and
available for failover.

