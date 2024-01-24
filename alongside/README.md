# Terraform example to launch bootc container image

This is a very small bit of Terraform code that uses the
[terraform-provider-google](https://github.com/hashicorp/terraform-provider-google)
to launch a single virtual machine in GCP.  The default
launched VM uses the standard `rhel-cloud/rhel-9` disk image.

However, the very important bit that is novel is that the Terraform logic
accepts a variable `bootc_image` which should be a bootc container image
reference (e.g. `quay.io/exampleos/somecustom:latest`).

The Terraform logic injects a "startup script" into the VM that executes
this code:

```terraform
  metadata_startup_script = <<-EOS
dnf -y install podman skopeo &&
podman run --rm --privileged -v /:/target --pid=host --security-opt label=type:unconfined_t ${var.bootc_image} bootc install to-filesystem --replace=alongside /target &&
reboot
EOS
```

This uses the [bootc install alongside](https://github.com/containers/bootc/blob/main/docs/install.md#using-bootc-install-to-filesystem---replacealongside)
logic to *entirely replace the VM root filesystem*.

## Nothing GCE specific about this

This same technique can work in AWS, Azure, etc. too - any IaaS
where you can inject metadata to run `podman`.

## Versus creating custom disk images

Some use cases will want to make custom *disk images* from
the container filesystem.  This is entirely possible and makes sense
in some cases.

However, it also imposes the costs of managing versioning and garbage
collection of those disk images onto the user.

Instead, with an approach like this you can avoid that cost and
focus on the container image as source of truth.

## Compare with terraform-provider-google/content-based-load-balancing example

See e.g. [this code](https://github.com/hashicorp/terraform-provider-google/blob/9d577db230bead275a4a1a6ae2c15a608a9dba1b/examples/content-based-load-balancing/scripts/install-video.sh)
and compare with managing that shell script as a container build.
