terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.85.0"
    }
  }
}

provider "yandex" {
  token     = "y0__xDD8-C3AhjB3RMg85DswBIvEZiwCEtQSU-HG2LC5daLe6OF2w"
  cloud_id  = "b1go28imjr51g14b7fno"
  folder_id = "b1g5dm0qbb0e6lmlkf2g"
  zone      = "ru-central1-a"
}


resource "yandex_vpc_network" "network" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "my-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}


resource "yandex_compute_instance" "vm" {
  count = 2
  name  = "vm-${count.index}"
 
  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 20.04
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\npackages: [nginx]\nruncmd: [systemctl, enable, --now, nginx]"
    ssh-keys  = "ubuntu:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC08CZafmwhOejaF/aDJBhWPT6KJeZ1vLVd+rryu7oMl3v7yLAgtMJca5tDI61cv+KA3V4fGi9YeTRUiWeXvvU47xbADb9GXslaA4aM1jj9SjBWXfcUyQFxCVlv/IE/u7o9c0spSzH3QFHMYBrTU912p9LQz8J23+mj0Xsloxz911AqMZVsjyhNIEqJPUWkmOjzjMzcqP5HThmEOEVkoveDmOgVU/20jZEHQsgOAgg66tWzH15AvwIWfjzLihABXQBSGsWnSxfgeGpQkfOBREWbwpsDXHEmg6vGdDhX1r34CPC33YqA9WMeJo+a+mafKEdUBT0gcjehj1lpN4BZC39CaFFLOeithukg1fXtrgAmPwEMxkV+hfb3JBc8kXD688Rw/hyOMRHbqChAerjPjSQnUdB/ulHLIVxnCeb9LSrUcpPxUD8GF8jHF9TRx5Yu9McY7RoBT3V834fCOD1ggOZ1OVnID1Hk3v3DYOialWJf7ZwoUnZBzd051oE5vIPMx70= ras2@DESKTOP-U7UHP4K"
  }
}


resource "yandex_lb_target_group" "tg" {
  name      = "nginx-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet.id
    address   = yandex_compute_instance.vm[0].network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet.id
    address   = yandex_compute_instance.vm[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = "nginx-balancer"

  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.tg.id
   
    healthcheck {
      name = "http-check"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

output "load_balancer_ip" {
  value = yandex_lb_network_load_balancer.lb.listener[*].external_address_spec[*].address
}

output "vm_ips" {
  value = yandex_compute_instance.vm[*].network_interface.0.nat_ip_address
}
