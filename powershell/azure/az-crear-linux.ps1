#break
# #############################################################################
# Deploy Linux Debian 9 VMs to Azure with PowerShell
#
# Repo:   scripts
# AUTHOR: Iván Rey
# EMAIL:  ireyagun@gmail.com
#
# DATE: 31/01/2018
# #############################################################################
 

### Variable list

#$mySubscription = 
$myResourceGroup = 'RG-debian9'
$myStorageAccount = 'stdebian9' #Solo numeros y minusculas
$myLocation = 'westeurope'
#$MyComputerName ='debian9'
$myVnet = 'net10'
$mySubnet = 'subnet0'
$myPublicIp = 'publicIP1'
$myNic ='nic1'

#Función para registrar los resource providers necesarios
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registrando resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}


Write-Host "VM Linux Debian 9 Standard_A0 (1 vcpu, 768 MB)"

Write-Host "=============================================="
Write-Host "VARIABLES"


$mySubscription = Read-Host "Subscripción";
#$myResourceGroup = Read-Host "Resource Group (ej. RG-debian9)";
#$myStorageAccount = Read-Host "Storage Account (ej. stdebian9)"; #Solo numeros y minusculas
#$myLocation = Read-Host "Localizacion (ej. westeurope)";
$MyComputerName = Read-Host "Hostname";
#$myVnet = Read-Host "Nombre Red (ej. vnet10)";
#$mySubnet = Read-Host "Nombre Subnet (ej. subnet0)";
#$myPublicIp = Read-Host "Nombre Ip publica (ej. publicipdebian1)";
#$myNic =Read-Host "Nombre NIC (ej. nicdebian1)";

Write-Host "=============================================="


# Login
Write-Host "Autenticando ...";
Login-AzureRmAccount

# Seleccion de suscripcion
Write-Host "Seleccionando subscripcion '$mySubscription'";
Select-AzureRmSubscription -SubscriptionName $mySubscription


# Registro Resource Providers
$resourceProviders = @("microsoft.compute","microsoft.network","microsoft.recoveryservices","microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registrando los resource providers necesarios"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Creo un nuevo resource group
Write-Host "Creando resource group '$myResourceGroup' en '$myLocation'";
New-AzureRmResourceGroup -Name $myResourceGroup -Location $myLocation


#Creo un storage account standard LRS NUEVO para la maquina
Write-Host "Creando storage account en '$myResourceGroup' en '$myLocation'";
New-AzureRmStorageAccount -ResourceGroupName $myResourceGroup -Name $myStorageAccount -SkuName Standard_LRS -Kind Storage -Location $myLocation

#hago que sea el almacenamiento por defecto
#Set-AzureRmCurrentStorageAccount -ResourceGroupName $myResourceGroupName -AccountName $myStorageAccount

#Write-Host "Claves del Storage Account"
#Get-AzureRmStorageAccountKey -ResourceGroupName $myResourceGroup -Name $myStorageAccount

#obtengo las claves
$Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $myResourceGroup -Name $myStorageAccount

#uso la primera clave
$storageContext = New-AzureStorageContext -StorageAccountName $myStorageAccount -StorageAccountKey $Keys[0].Value

#creo un nuevo container para el disco
Write-Host "Creando contenedor 'vhds'"
New-AzureStorageContainer -Name 'vhds' -Context $storageContext



#creo una subred
Write-Host "Creando subred"
$mySubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $mySubnet -AddressPrefix 10.0.0.0/24

Write-Host "Creando virtual network"
$myVnet = New-AzureRmVirtualNetwork -Name $myVnet -ResourceGroupName $myResourceGroup -Location $myLocation -AddressPrefix 10.0.0.0/16 -Subnet $mySubnet

Write-Host "Creando ip publica dinamica"
$myPublicIp = New-AzureRmPublicIpAddress -Name $myPublicIp -ResourceGroupName $myResourceGroup -Location $myLocation -AllocationMethod Dynamic

Write-Host "Creando una NIC"
$myNIC = New-AzureRmNetworkInterface -Name $myNIC -ResourceGroupName $myResourceGroup -Location $myLocation -SubnetId $myVnet.Subnets[0].Id -PublicIpAddressId $myPublicIp.Id

Write-Host "Asignando credenciales"
$cred = Get-Credential -Message "Usuario y contraseña del administrador local."

#listado de los tamaños de maquina en esta ubicacion
### Get-AzureRmVMSize -Location $myLocation

#le doy tamaño a mi maquina y un nombre
Write-Host "Asignando tamaño de VM"
$myVM = New-AzureRmVMConfig -VMName $MyComputerName -VMSize 'Standard_A0'  #1 cpu 768 MB

Write-Host "Asignando tipo de sistema, nombre de VM y credenciales"
$myVM = Set-AzureRmVMOperatingSystem -VM $myVM -ComputerName $MyComputerName -Linux -Credential $cred

#listado de publicadores
#Get-AzureRmVMImagePublisher -Location $myLocation | Select-Object -Property PublisherName


#listado de  imagenes
#Get-AzureRmVMImageSku -Location $myLocation -PublisherName 'RedHat' -Offer 'RHEL'


#le asigno red hat
#$myVM = Set-AzureRmVMSourceImage -VM $myVM -PublisherName 'RedHat' -Offer 'RHEL' -Skus '7.2' -Version 'latest'

#listado de publicadore credativ
### Get-AzureRmVMImagePublisher -Location $myLocation |  Where-Object -FilterScript {($_.Publishername -eq 'credativ')}

#listado imagenes
### Get-AzureRmVMImageSku -Location $myLocation -PublisherName 'credativ' -Offer 'Debian'


#le asigno debian 9 de credativ
Write-Host "Asignando imagen de S.O."
$myVM = Set-AzureRmVMSourceImage -VM $myVM -PublisherName 'credativ' -Offer 'Debian' -Skus '9' -Version 'latest'

Write-Host "Asignando NIC"
$myVM = Add-AzureRmVMNetworkInterface -VM $myVM -Id $myNIC.Id

Write-Host "Añadiendo disco"
$myVM = Set-AzureRmVMOSDisk -VM $myVM -Name 'myOsDisk01' -VhdUri 'https://stdebian9.blob.core.windows.net/vhds/myosdisk01.vhd' -CreateOption FromImage #-Linux


Write-Host "Creando la VM en '$myResourceGroup' en '$myLocation'"
New-AzureRmVM -ResourceGroupName $myResourceGroup -Location $myLocation -VM $myVM


#lista las maquinas que hay en un grupo de recursos
Write-Host "Listado VMS en el grupo de recursos"
Get-AzureRmVM -ResourceGroupName $myResourceGroup



