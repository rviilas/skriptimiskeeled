#!/bin/bash
#Rain Viilas
#See skript installib süsteemi samba, loob vajadusel ettemääratudkausta
#kausta ja grupi ning muudab samba confi faili

#sudo bash ./skript.sh KAUST grupp SHARE

export LC_ALL=C

#Kontrollib kas skript on käivitatud juurkasutajana

if [ $UID -ne 0  ]
then
    echo "Käivita skript $(basename $0) juurkasutaja õigustes"
    return 1
fi


#Kontrollib, kas on ette antud õige arv  muutujaid

if [ $# -eq 2 ]
then
    KAUST=$1
    GRUPP=$2
else
    if [ $# -eq 3 ]
    then
        KAUST=$1
        GRUPP=$2
        SHARE=$3
    else
        echo "kasuta skripti $(basename $) jaga KAUST grupp [SHARE]"
        exit 1
    fi
fi


#Kontrollib kas samba on juba masinas olemas, kui ei ole siis installib.

dpkg -s samba > /dev/null 2>&1

if [ $? -ne 0 ]
then
    echo "Sambat ei ole masinasse installitud. Installin samba." 
    apt-get update > /dev/null 2>&1 && apt-get install samba smbclient cifs-utils -y || echo "Samba install ebaõnnestus" && exit 1
else
    echo "Samba on installitud." 
fi
  

#Kontrollib kas kasutaja määratud kaust on juba olemas, kui ei ole siis loob selle kausta.
  
if [ ! -d "$KAUST" ]
then
    echo "Loon kausta $KAUST"
    mkdir -p /home/student/$KAUST || echo "Kausta loomine ebaõnnestus!" && exit 1
else
    echo "Kaust on juba olemas."
fi


#Kontrollib kas kasutaja määratud grupp on juba olemas, kui ei ole siis loob selle grupi.

getent group $GRUPP > /dev/null 2>&1
if [ $? -ne 0 ]
then
    addgroup --system $GRUPP || echo "Grupi loomine ebaõnnestus!" && exit 1
else
    echo "Grupp on juba olemas."
fi
#Kuna loodud kaust ja grupp sai tehtnud sudona siis tuleb omanlikkus ära muuta
#selleks, et tehtud grupp saaks kausta kasutada.
sudo chown $USER:$GRUPP $KAUST
sudo chmod g+w $KAUST

#Teeb samba configuratsioonifailist koopia    
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.old

#Kirjutan smb.confi koopia faili kasutades cati ja <<sõna >> mis tähistab inputi lugemise algust kuni see sama sõna uuesti esineb. Kasutasin EOT mis tähistab kommunikatsioonis end of transmissionit.
echo "Lisan smb.conf faili vastavad read."
cat <<EOT >> /etc/samba/smb.conf.old
[Jagatud kaust]
comment=Jagatud kaust
path=/home/student
writable=yes
valid users=@$GRUPP
force group=$GRUPP
browsable=yes
create mask=0664
directory mask=0775
EOT

#Kasutades testparmi proovin järgi kas confi fail töötab. Kui töötab siis kirjutan
#andmed õigesse confi faili. Kustutan ära koopia confi ja taastkäivitan samba.
testparm -s /etc/samba/smb.conf.old > /dev/null 2>&1
if [ $? -eq 0 ]
then
    cat <<EOT >> /etc/samba/smb.conf
    [Jagatud kaust]
    comment=Jagatud kaust
    path=/home/student
    writable=yes
    valid users=@$GRUPP
    force group=$GRUPP
    browsable=yes
    create mask=0664
    directory mask=0775
EOT
else
    echo "Conf ei töötanud." && exit 1
fi 

rm /etc/samba/smb.conf.old && sudo service smbd restart > /dev/null 2>&1 && echo "Kõik õnnestus!"
