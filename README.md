# opsworks_local
Run OpsWorks recipes via command line on EC2 instances. By default, the recipe targets the EC2 instance where the command was run, but this can be changed.

# Usage
```
# Deploy all applications to current instance
$ ruby opsworks_local.rb -c deploy

# Invoke deploy on another server instance
$ ruby opsworks_local.rb -c deploy -i i-7f9811b1

# Run custom recipe to current instance
$ ruby opsworks_lcoal.rb -r mycookbook::jump_high

```

# Prerequisites

* `aws-cli` package must be installed.


# Design Goals

Initially, the goal of this script is to enable an OpsWorks recipe to be run as a cron job. The cron job will be deployed via the `cron` resource of Chef/OpsWorks. Thus, I wanted a dependency-free, bloat-free script that can be placed anywhere, and made to run by any system user via a simple line of script. This means no `Gemfiles`, and no bundling. 

I also intentionally did not use the `aws-sdk` gem, due to the reasons above.

# License

Copyright (c) 2015, Ardee Aram.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of the FreeBSD Project.





