STREAM ?= stable
IMAGES_DIR:=./images


# Download the latest stable Fedora CoreOS image.
#
# Source: https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/
.PHONY: download-fedora-coreos
download-fedora-coreos:
	mkdir --parents ${IMAGES_DIR}
	coreos-installer download -s "${STREAM}" \
		--platform qemu \
		--format qcow2.xz \
		--decompress \
		--directory=${IMAGES_DIR}


# Download the latest bootable Fedora cloud image.
#
# Source: https://github.com/CentOS/centos-boot-layered/tree/main/fedora-boot-cloud
.PHONY: download-fedora-cloud
download-fedora-cloud:
	mkdir -p ${IMAGES_DIR}
	curl https://storage.googleapis.com/centos-boot-dev/fedora-boot-cloud.qcow2 -o ${IMAGES_DIR}/fedora-boot-cloud.qcow2


# virt-install requires most paths to be absolute, so try defaulting to
# absolute as much as possible.
IGNITION_CONFIG ?= $(realpath ignition.ign)
BUTANE_CONFIG ?= $(realpath butane.bu)

# Build the ignition file that we need later on to boot and setup Fedora
# CoreOs.  For building the ignition file, we're making use of another
# configuration called Butane which is more human friendly.  The Butane file is
# then compiled into an ignition.
#
# Source: https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/
.PHONY: ignition
ignition:
	podman run --interactive --rm quay.io/coreos/butane:release \
		--pretty --strict < ${BUTANE_CONFIG} > ${IGNITION_CONFIG}

# When running inside a VM, the virbr0 and default libvirt network may already
# be occupied.  So make it easy to create another network to create the
# virbrplayground bridge.
.PHONY: network-setup
network-setup:
	sudo virsh net-create --file=network.xml

# Those knobs are currently undocumented but can played with if needed.
VM_NAME ?= bootc-playground
VM_NETWORK ?= virbr0
VCPUS ?= 2
RAM_MB ?= 4096
DISK_GB ?= 10
IMAGE ?= ${IMAGES_DIR}/$(shell ls -1c ${IMAGES_DIR}|head -n1)

ifneq ($(VM_MOUNT),)
VM_MOUNT_ARGS=--filesystem=$(realpath ${VM_MOUNT}),playground-mount,driver.type=virtiofs --memorybacking=source.type=memfd,access.mode=shared
endif

# Source: https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/#_booting_on_a_local_hypervisor_libvirt_example
.PHONY: vm-install-ignition
vm-install-ignition:
	@echo "Installing a new VM (${VM_NAME}) with image ${IMAGE} **via ignition**."
	@echo "Set the VM_MOUNT environment variable to mount a host directory into the VM."
	@echo "The VM_MOUNT gets automatically mounted to /var/playground."
	@echo "If the network step failed, run 'make network-setup' and set 'VM_NETWORK=virbrplayground'."
	@echo ""

	chcon --verbose --type svirt_home_t ${IGNITION_CONFIG}
	sudo virt-install \
		--connect="qemu:///system" \
		--name="${VM_NAME}" \
		--cpu=host \
		--vcpus="${VCPUS}" \
		--memory="${RAM_MB}" \
		--os-variant="detect=on,name=fedora-coreos-${STREAM}" \
		--import \
		--graphics=none \
		--disk="size=${DISK_GB},backing_store=$(realpath ${IMAGE})" \
		--network bridge=${VM_NETWORK} \
		${VM_MOUNT_ARGS} \
		--qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_CONFIG}"


.PHONY: vm-install-cloud
vm-install-cloud:
	@echo "Installing a new VM (${VM_NAME}) with image ${IMAGE} **via clout-init**."
	@echo "Set the VM_MOUNT environment variable to mount a host directory into the VM."
	@echo "The VM_MOUNT gets automatically mounted to /var/playground."
	@echo "If the network step failed, run 'make network-setup' and set 'VM_NETWORK=virbrplayground'."
	@echo ""

	sudo virt-install \
		--connect="qemu:///system" \
		--name="${VM_NAME}" \
		--cpu=host \
		--vcpus="${VCPUS}" \
		--memory="${RAM_MB}" \
		--os-variant="detect=on,name=fedora-unknown" \
		--import \
		--graphics=none \
		--disk="size=${DISK_GB},backing_store=$(realpath ${IMAGE})" \
		--network bridge=${VM_NETWORK} \
		${VM_MOUNT_ARGS} \
		--cloud-init user-data=$(realpath ./cloud-init.yaml)


# Some convenience targets to manage the VM.
#
# Source: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/part-administration
.PHONY: vm-start
vm-start:
	@echo "Starting VM ${VM_NAME}.  Run 'make vm-ip' in case you forgot the IP."
	@echo ""

	sudo virsh start ${VM_NAME}


.PHONY: vm-ip
vm-ip:
	sudo virsh net-dhcp-leases default


.PHONY: vm-stop
vm-stop:
	@echo "Shutting down VM ${VM_NAME}.  May take a moment to take effect."
	@echo ""

	sudo virsh shutdown --domain ${VM_NAME}


.PHONY: vm-remove
vm-remove:
	@echo "Removing VM ${VM_NAME} and all its storage.  Make sure to 'make vm-stop' before."
	@echo ""

	sudo virsh undefine ${VM_NAME} --remove-all-storage
