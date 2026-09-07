output "kali_public_ip" {
  value       = aws_instance.kali.public_ip
  description = "Public IP of the Kali Attacker Box"
}

output "windows_public_ip" {
  value       = aws_instance.windows.public_ip
  description = "Public IP of the Windows Target Server"
}

output "ubuntu_siem_public_ip" {
  value       = aws_instance.ubuntu_siem.public_ip
  description = "Public IP of the Ubuntu Security Box"
}
