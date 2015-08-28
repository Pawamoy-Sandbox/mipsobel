.data
nonbmp: .asciiz "Fichier non reconnu comme BMP"
inputfile: .space 32 # défini par le programmeur
outputfile: .space 39 # = taille de l'inputfile + 7 (taille du mot Contour)
Contour: .asciiz "Contour"
TailleTotale: .asciiz "Taille totale du fichier : "
Offset: .asciiz "Offset : "
Largeur: .asciiz "Largeur : "
Hauteur: .asciiz "Hauteur : "
Profondeur: .asciiz "Profondeur : "
TailleImage: .asciiz "Taille totale de l'image : "
NombreCouleurs: .asciiz "Nombre de couleurs : "
Resolution: .asciiz "Résolution : "
.align 1
RetChar: .asciiz "\n"
.align 1
EOL: .asciiz "\0"
.align 1
Point: .asciiz "."
.align 2
bufSign: .asciiz "AA"
.align 2
sign: .asciiz "BM"
.align 2
bufPro: .space 2
.align 4
bufTT: .space 4
.align 4
bufOff: .space 4
.align 4
bufLar: .space 4
.align 4
bufHau: .space 4
.align 4
bufNbrC: .space 4
.align 4
bufPal: .space 4
.align 4
bufTI: .space 4
.align 4
bufRV: .space 4
.align 4
bufRH: .space 4
.align 4
bufInt: .space 4 # utilisé seulement pour la lecture de données inutilisées

.text
.globl __start

__start:


#########################################################
#######                    MAIN                   #######
#########################################################

####### Ouvrir le fichier lena.bmp et récupérer adresse du premier octet dans $v0
la $a0 inputfile # adresse de la chaine filename dans $a0
li $a1 31
jal DemanderNomFichier
jal OuvrirFichier
move $s0 $v0 # on copie le descripteur de fichier dans $s0

####### Lire la signature
move $a0 $s0 # on met le descripteur de fichier dans $a0
la $a1 bufSign # adresse de la chaine de reception des caracteres lus dans $a1
jal Read2Bytes

####### Vérification de la signature
la $a2 sign # adresse de la chaine de comparaison dans $a2
lb $t8 0($a1) # on charge l'octet (lb) à l'adresse $a1+0 dans $t8 : 1ere lettre lue
lb $t9 0($a2) # ________________________________________$a2+0 dans $t9 : lettre B
bne $t8 $t9 BMP # verif premiere lettre
lb $t8 1($a1) # on charge l'2 octet (lb) à l'adresse $a1+1 dans $t8 : 2eme lettre lue
lb $t9 1($a2) # ________________________________________$a2+1 dans $t9 : lettre M
bne $t8 $t9 BMP # verif deuxieme lettre

####### Fichier validé : on crée le nom de fichier de sortie
la $a0 inputfile
la $a1 outputfile
jal OutputName

####### Récupérer les données des entetes du fichier BMP dans les buffers
move $a0 $s0
jal ReadHeaders

####### Lecture et sauvegarde de la palette en mémoire
jal ReadPalette
move $s1 $v0 # on sauvegarde l'adresse de la palette en mémoire dans $s1

####### Lecture et sauvegarde de la matrice en mémoire
jal ReadMatrix
move $s2 $v0 # on sauvegarde l'adresse de la matrice en mémoire dans $s2

####### Toutes les données ont été récupérées, on ferme le fichier
li $v0 16
syscall

####### Affichage des infos
# headers
# jal PrintHeaders
# palette
# move $a0 $s1
# jal PrintPalette
# matrice
# move $a0 $s2
# la $a2 bufLar
# lw $a1 0($a2)
# jal PrintMatrice

####### Allocation des espaces mémoires correspondants aux matrices Gx et Gy
move $a0 $v1
li $v0 9
syscall
move $s3 $v0 # adresse de Gx dans $s3
li $v0 9
syscall
move $s4 $v0 # adresse de Gy dans $s4

####### Calcul des matrices Gx et Gy
move $a0 $s2
move $a1 $s3
li $a2 150 # seuil s
li $a3 0 # calcul de Gx
jal CalculerGXY
move $a1 $s4
li $a3 1 # calcul de Gy
jal CalculerGXY

# move $a0 $s3
# la $a2 bufLar
# lw $a1 0($a2)
# jal PrintMatrice

####### Addition de ces deux matrices (résultat dans Gx)
move $a0 $s3
move $a1 $s4
jal AddMatrices

####### On crée le nouveau fichier
la $a0 outputfile
jal CreerFichier
move $s0 $v0 # on stocke le file descriptor dans $s0 (plus besoin de celui du fichier source)
move $a0 $s0 # argument 1 pour WriteOutput : file descriptor
move $a1 $s3 # argument 2 pour WriteOutput : adresse de la matrice
jal WriteOutput

####### Ecriture du fichier terminée, on peut le fermer
li $v0 16
syscall

####### Fin du programme
j Exit





#########################################################
#######                 FONCTIONS                 #######
#########################################################


###################################################################################################################
###################################################################################################################
####### Fonctions permettant de lire un fichier au format BMP


############################################################################
### Lire les entetes d'un fichier BMP (sauvegarde dans des buffers)
# Entrées: $a0: descripteur de fichier
# Pré-conditions: $a0 > 0
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
ReadHeaders:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $a1 4($sp)
# corps
####### Lire la taille totale
la $a1 bufTT # idem
jal Read4Bytes # on lit 4 octets (un entier), stockés dans $a1 (qui est une adresse)
####### Lire le champ réservé
la $a1 bufInt # buffer pour les données non utilisées
jal Read4Bytes
####### Lire l'offset
la $a1 bufOff
jal Read4Bytes
####### Lire la taille de l'entete
la $a1 bufInt
jal Read4Bytes
####### Lire la largeur
la $a1 bufLar
jal Read4Bytes
####### Lire la hauteur
la $a1 bufHau
jal Read4Bytes
####### Lire le nombre de plans
la $a1 bufSign # à ce niveau là on n'a plus besoin de la signature
jal Read2Bytes
####### Lire la profondeur
la $a1 bufPro
jal Read2Bytes
####### Lire la méthode de compression
la $a1 bufInt
jal Read4Bytes
####### Lire la taille totale de l'image
la $a1 bufTI
jal Read4Bytes
####### Lire la résolution horizontale
la $a1 bufRH
jal Read4Bytes
####### Lire la résolution verticale
la $a1 bufRV
jal Read4Bytes
####### Lire le nombre de couleurs de la palette
la $a1 bufNbrC
jal Read4Bytes
####### Lire le nombre de couleurs importantes de la palette
la $a1 bufInt
jal Read4Bytes
# epilogue
lw $ra 0($sp)
lw $a1 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Lire la palette (sauvegarde dans le tas)
# Entrées: $a0: descripteur du fichier BMP
# Pré-conditions: 
# Sorties: $v0: adresse du 1er octet de l'espace alloué (contenant la palette)
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
ReadPalette:
# prologue
subu $sp $sp 20
sw $ra 0($sp)
sw $a0 4($sp)
sw $a1 8($sp)
sw $s0 12($sp)
sw $s1 16($sp)
# corps
la $a1 bufNbrC # on stocke l'adresse de bufNbrC dans $a1
lw $a0 0($a1) # on lit un entier à cette adresse (=nombre de couleurs)
move $s1 $a0 # on sauvegarde le nombre de couleurs dans $s1
li $t0 3 # facteur de multiplication pour l'espace alloué (1octet par constante:rouge-vert-bleu)
mul $a0 $a0 $t0 # on multiplie $a0 par $t0
li $v0 9 # appel système 9
syscall # on alloue nbrCouleurs*3
move $s0 $v0 # on copie $v0 dans $s0
# au lieu d'utiliser une boucle et un buffer temporaire
# j'aurai pu stocker toute la palette en mémoire
# grace a ReadNBytes (avec les bons arguments)
# mais je souhaitais optimiser l'espace en mémoire (de peu, certes)
# en ne stockant pas les champs réservés de chaque couleur (toujours 0)
lw $a0 4($sp) # on remet le descripteur de fichier dans $a0
la $a1 bufInt # buffer de 4 octets
BoucleRP:
beq $s1 $zero FinBoucleRP # si on a récupéré toutes les couleurs, on break
jal Read4Bytes # on lit dans $a0, on écrit dans $a1
lb $t0 0($a1) # on charge la composante rouge dans $t0
lb $t1 1($a1) # _______________________ verte ____ $t1
lb $t2 2($a1) # _______________________ bleue ____ $t2
sb $t0 0($s0) # on écrit la composante rouge dans $s0
sb $t1 1($s0) # ______________________ verte ____ $s0+1
sb $t2 2($s0) # ______________________ bleue ____ $s0+2
addi $s0 $s0 3 # on se déplace de 3 dans l'espace mémoire alloué de la palette
subu $s1 $s1 1 # on décrémente le nombre de couleurs
j BoucleRP # on boucle
FinBoucleRP:
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a1 8($sp)
lw $s0 12($sp)
lw $s1 16($sp)
addi $sp $sp 20
jr $ra
############################################################################

############################################################################
### Lire la matrice de l'image (sauvegarde dans le tas)
# Entrées: $a0: descripteur du fichier BMP
# Pré-conditions: 
# Sorties: $v0: adresse du 1er octet de l'espace alloué (contenant la matrice)
#	   $v1: taille de la matrice en octets (pour allouer Gx et Gy)
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
ReadMatrix:
# prologue
subu $sp $sp 36
sw $ra 0($sp)
sw $a0 4($sp)
sw $a1 8($sp)
sw $a2 12($sp)
sw $s0 16($sp)
sw $s1 20($sp)
sw $s2 24($sp)
sw $s3 28($sp)
sw $s4 32($sp)
# corps
la $s1 bufLar # s1=adresse du buffer Largeur
lw $s0 0($s1) # s0=Largeur
la $s1 bufPro # s1=adresse du buffer Profondeur
lw $s2 0($s1) # s2=Profondeur
la $s1 bufHau # s1=adresse du buffer Hauteur
lw $s4 0($s1) # s4=Hauteur
mul $s1 $s0 $s2 # s1 = s0 * s2 (largeur*profondeur)
li $s3 8 # s3=8
div $s1 $s3
mfhi $s1 # s1 = s1%s3 (largeur*profondeur mod 8)
mflo $s3 # s3 = s1/s3 (largeur*profondeur/8)
move $t0 $s4
move $t1 $s3
move $t2 $s1
# à ce niveau là on a :
# t0 = s4 = nbr de ligne (pixel/colonne)
# t1 = s3 = nbr d'octets par ligne
# t2 = s1 = nbr d'octet à lire en plus à chaque fin de ligne
#      s0 = nbr de pixel par ligne
#      s2 = nbr de colonne (pixel/ligne)
li $v0 9
mul $a0 $t0 $t1
move $v1 $a0
syscall
move $t3 $v0 # adresse espace alloué dans t3
lw $a0 4($sp) # descripteur de fichier dans a0
move $a2 $t1 # init nbr d'octet à lire par ligne
BoucleRM:
beqz $t0 FinBoucleRM
move $a1 $t3 # adresse buffer (espace alloué) dans a1
jal ReadNBytes
add $t3 $t3 $t1 # on se déplace de t1 octets dans l'espace t3
beqz $t2 ContinueRM
la $a1 bufInt
move $a2 $t2
jal ReadNBytes
move $a2 $t1
ContinueRM:
subu $t0 $t0 1
j BoucleRM
FinBoucleRM:
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a1 8($sp)
lw $a2 12($sp)
lw $s0 16($sp)
lw $s1 20($sp)
lw $s2 24($sp)
lw $s3 28($sp)
lw $s4 32($sp)
addi $sp $sp 36
jr $ra
############################################################################



###################################################################################################################
###################################################################################################################
####### Fonctions d'affichage


############################################################################
### Afficher un nombre
# Entrées: $a0: entier à afficher
# Pré-conditions: 
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
AfficherNombre:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $v0 4($sp)
# corps
li $v0 1
syscall
# epilogue
lw $ra 0($sp)
lw $v0 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Afficher une chaine
# Entrées: $a0: adresse de la chaine à afficher
# Pré-conditions: 
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
AfficherChaine:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $v0 4($sp)
# corps
li $v0 4
syscall
# epilogue
lw $ra 0($sp)
lw $v0 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Afficher un saut de ligne
# Entrées:
# Pré-conditions: 
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
SautDeLigne:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $a0 4($sp)
# corps
la $a0 RetChar
jal AfficherChaine
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Afficher les entetes du fichier BMP
# Entrées:
# Pré-conditions: les buffers ont été remplis
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
PrintHeaders:
# prologue
subu $sp $sp 12
sw $a0 0($sp)
sw $a1 4($sp)
sw $ra 8($sp)
# corps
####### Afficher la taille totale
la $a0 TailleTotale
jal AfficherChaine
la $a1 bufTT
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
####### Afficher l'offset
la $a0 Offset
jal AfficherChaine
la $a1 bufOff
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
####### Afficher la largeur
la $a0 Largeur
jal AfficherChaine
la $a1 bufLar
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
####### Afficher la hauteur
la $a0 Hauteur
jal AfficherChaine
la $a1 bufHau
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
####### Afficher la profondeur
la $a0 Profondeur
jal AfficherChaine
la $a1 bufPro
lh $t8 0($a1)
move $a0 $t8
jal AfficherNombre
jal SautDeLigne
####### Afficher la résolution
la $a0 Resolution
jal AfficherChaine
la $a1 bufRH
lw $a0 0($a1)
jal AfficherNombre
la $a0 Point
jal AfficherChaine
la $a1 bufRV
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
####### Afficher la taille totale de l'image
la $a0 TailleImage
jal AfficherChaine
la $a1 bufTI
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
####### Afficher le nombre de couleurs de la palette
la $a0 NombreCouleurs
jal AfficherChaine
la $a1 bufNbrC
lw $a0 0($a1)
jal AfficherNombre
jal SautDeLigne
# epilogue
lw $a0 0($sp)
lw $a1 4($sp)
lw $ra 8($sp)
addi $sp $sp 12
jr $ra
############################################################################

############################################################################
### Afficher la palette
# Entrées: $a0: adresse de la palette
# Pré-conditions: 
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
PrintPalette:
# prologue
subu $sp $sp 16
sw $ra 0($sp)
sw $a0 4($sp)
sw $a1 8($sp)
sw $a2 12($sp)
# corps
la $a1 bufNbrC
lw $a2 0($a1)
move $t0 $a2
move $t1 $a0
BouclePP:
beqz $t0 FinBouclePP
lbu $a0 0($t1)
jal AfficherNombre
lbu $a0 1($t1)
jal AfficherNombre
lbu $a0 2($t1)
jal AfficherNombre
jal SautDeLigne
addi $t1 $t1 3
subu $t0 $t0 1
j BouclePP
FinBouclePP:
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a1 8($sp)
lw $a2 12($sp)
addi $sp $sp 16
jr $ra
############################################################################

############################################################################
### Afficher une matrice
# Entrées: $a0: adresse de la matrice
#	   $a1: taille (matrice supposée carrée)
# Pré-conditions: 
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
PrintMatrice:
# prologue
subu $sp $sp 16
sw $ra 0($sp)
sw $a0 4($sp)
sw $a1 8($sp)
sw $a2 12($sp)
# corps
move $t0 $a1
move $t1 $a0
move $t2 $a1
BouclePM2:
beqz $t2 FinBouclePM2
move $t0 $a1
BouclePM1:
beqz $t0 FinBouclePM1
lbu $a0 0($t1)
jal AfficherNombre
jal SautDeLigne
addi $t1 $t1 1
subu $t0 $t0 1
j BouclePM1
FinBouclePM1:
subu $t2 $t2 1
j BouclePM2
FinBouclePM2:
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a1 8($sp)
lw $a2 12($sp)
addi $sp $sp 16
jr $ra
############################################################################



###################################################################################################################
###################################################################################################################
####### Fonctions de lecture dans un fichier quelconque


############################################################################
### Lire 2 octets
# Entrées: $a0: descripteur de fichier
#	   $a1: adresse du buffer
# Pré-conditions: $a0 > 0
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
Read2Bytes:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $a2 4($sp)
# corps
li $a2 2
jal ReadNBytes
# epilogue
lw $ra 0($sp)
lw $a2 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Lire 4 octets
# Entrées: $a0: descripteur de fichier
#	   $a1: adresse du buffer
# Pré-conditions: $a0 > 0
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
Read4Bytes:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $a2 4($sp)
# corps
li $a2 4
jal ReadNBytes
# epilogue
lw $ra 0($sp)
lw $a2 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Lire N octets
# Entrées: $a0: descripteur de fichier
#	   $a1: adresse du buffer
#	   $a2: nombre d'octets à lire
# Pré-conditions: $a0 > 0
# Sorties: 
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
ReadNBytes:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $v0 4($sp)
# corps
li $v0 14
syscall
# epilogue
lw $ra 0($sp)
lw $v0 4($sp)
addi $sp $sp 8
jr $ra
############################################################################



###################################################################################################################
###################################################################################################################
####### Fonctions d'interaction avec l'utilisateur


############################################################################
### Demander un nom de fichier
# Entrées: $a0: input buffer
#	   $a1: nombre max de caracteres à lire
# Pré-conditions: $a0 > 0
# Sorties: $a0: buffer rempli et traité
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
DemanderNomFichier:
# prologue
subu $sp $sp 20
sw $ra 0($sp)
sw $v0 4($sp)
sw $a2 8($sp)
sw $a3 12($sp)
sw $s1 16($sp)
# corps
li $v0 8 # appel système 8
syscall # lecture d'une chaine, buffer=$a0, car.max=$a1
move $a3 $a0 # on copie l'adresse de début de buffer dans $a3
la $a2 RetChar # adresse de la chaine contenant \n dans $a2
lb $t9 0($a2) # on charge le code sur 1 octet du \n dans $t9
li $s1 0 # on initialise le compte de caractères
BoucleDNF:
beq $a1 $s1 FinBoucleDNF # si nombre de caractères traités == $a1, break
lb $t8 0($a3) # on stocke la lettre à l'adresse courante dans $t8
beq $t8 $t9 Remplacer # si car. \n détecté, on lance le remplacement
addi $a3 $a3 1 # on se déplace dans la chaine au caractère suivant
addi $s1 $s1 1 # on incrémente le compteur de caractères
j BoucleDNF # on boucle
Remplacer:
la $a2 EOL # adresse de la chaine contenant \0 dans $a2
lb $t9 0($a2) # on charge le code sur 1 octet du \0 dans $t9
sb $t9 0($a3) # on remplace le \n de $a3 par \0
FinBoucleDNF:
# epilogue
lw $ra 0($sp)
lw $v0 4($sp)
lw $a2 8($sp)
lw $a3 12($sp)
lw $s1 16($sp)
addi $sp $sp 20
jr $ra
############################################################################



###################################################################################################################
###################################################################################################################
####### Fonctions diverses


############################################################################
### Fichier non reconnu comme BMP
BMP:
la $a0 nonbmp
jal AfficherChaine
jal SautDeLigne
j Exit
############################################################################

############################################################################
### Quitter le programme
Exit:
li $v0 10 # appel systeme 10 pour quitter
syscall
############################################################################

############################################################################
### Ouvrir un fichier en lecture seule
# Entrées: $a0: adresse de la chaine contenant le nom de fichier à ouvrir
# Pré-conditions: 
# Sorties: $v0: descripteur de fichier
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
OuvrirFichier:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $a1 4($sp)
# corps
li $a1 0
li $v0 13 # appel systeme 13 pour ouvrir un fichier en mémoire
syscall
# epilogue
lw $ra 0($sp)
lw $a1 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Créer un fichier pour écrire dedans
# Entrées: $a0: adresse de la chaine contenant le nom de fichier à créer
# Pré-conditions: 
# Sorties: $v0: descripteur de fichier
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
CreerFichier:
# prologue
subu $sp $sp 8
sw $ra 0($sp)
sw $a1 4($sp)
# corps
li $a1 1
li $v0 13 # appel systeme 13 pour ouvrir un fichier en mémoire
syscall
# epilogue
lw $ra 0($sp)
lw $a1 4($sp)
addi $sp $sp 8
jr $ra
############################################################################

############################################################################
### Définir le nom du fichier contour
# Entrées: $a0: adresse de la chaine contenant le nom du fichier input
#	   $a1: adresse de la chaine recevant le nom du fichier output
# Pré-conditions: la chaine intput se termine par \0
# Sorties: $a1: chaine remplie
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
OutputName:
# prologue
subu $sp $sp 24
sw $ra 0($sp)
sw $a0 4($sp)
sw $a1 8($sp)
sw $a2 12($sp)
sw $a3 16($sp)
sw $s0 20($sp)
# corps
la $a2 Point # adresse de la chaine contenant \0 dans $a2
lb $t9 0($a2) # on charge le code sur 1 octet du point dans $t9
BoucleON1:
lb $t1 0($a0) # on lit un caractère dans $a0
beq $t1 $t9 Ajouter # si c'est un point on va à Ajouter
sb $t1 0($a1) # sinon on le copie dans $a1
addi $a0 $a0 1 # on se déplace d'un octet dans $a0
addi $a1 $a1 1 # on se déplace d'un octet dans $a1
j BoucleON1 # on boucle
Ajouter:
move $s0 $a0 # on sauvegarde l'emplacement du point dans la chaine dans $s0
la $a3 Contour # adresse de la chaine contenant le mot Contour dans $a3
li $t2 0 # init compteur car
li $t3 7 # init limite compteur
BoucleON2:
beq $t2 $t3 FinBoucleON2 # si limite atteinte, on break
lb $t1 0($a3) # on récupère un car. de "Contour"
sb $t1 0($a1) # on l'écrit dans $a1
addi $t2 $t2 1 # on incrémente le compteur
addi $a1 $a1 1 # on se déplace d'un octet dans $a1
addi $a3 $a3 1 # on se déplace d'un octet dans $a3
j BoucleON2
FinBoucleON2:
lb $t1 0($a0) # on récup "."
sb $t1 0($a1) # on l'écrit dans $a1
lb $t1 1($a0) # on récup "b"
sb $t1 1($a1) # on l'écrit dans $a1
lb $t1 2($a0) # on récup "m"
sb $t1 2($a1) # on l'écrit dans $a1
lb $t1 3($a0) # on récup "p"
sb $t1 3($a1) # on l'écrit dans $a1
# addi $a1 $a1 4 # on se déplace de 4 octets dans la chaine $a1
la $a2 EOL # adresse de la chaine contenant \0 dans $a2
lb $t9 0($a2) # on charge le code sur 1 octet du \0 dans $t9
sb $t9 4($a1) # on écrit le \0 à la fin de $a1
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a1 8($sp)
lw $a2 12($sp)
lw $a3 16($sp)
lw $s0 20($sp)
addi $sp $sp 24
jr $ra
############################################################################



###################################################################################################################
###################################################################################################################
####### Fonctions d'accessions à des éléments en mémoire


############################################################################
### Accéder à une couleur de la palette selon son indice
# Entrées: $a0: adresse du premier octet de la palette
#	   $a1: indice de la couleur à récupérer (0<=i<NbrC)
# Pré-conditions: 
# Sorties: $v0: contient la couleur (RVB0)
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
GetColor:
# prologue
subu $sp $sp 12
sw $ra 0($sp)
sw $a0 4($sp)
sw $a2 8($sp)
# corps
move $t0 $a1
li $t1 3
mul $t0 $t0 $t1
add $a0 $a0 $t0
la $a2 bufInt
lb $t0 0($a0)
lb $t1 1($a0)
lb $t2 2($a0)
sb $t0 0($a2)
sb $t1 1($a2)
sb $t2 2($a2)
li $t0 0
sb $t0 3($a2)
lw $v0 0($a2)
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a2 8($sp)
addi $sp $sp 12
jr $ra
############################################################################

############################################################################
### Récupérer la composante d'une couleur
# Entrées: $a0: la couleur
#	   $a1: indice de la composante (1=Rouge, 2=Vert, 3=Bleu)
# Pré-conditions: 
# Sorties: $v0: contient la composante
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
GetRVB:
# prologue
subu $sp $sp 12
sw $ra 0($sp)
sw $a0 4($sp)
sw $a2 8($sp)
# corps
la $a2 bufInt
lw $a0 0($a2)
add $a2 $a2 $a1
subu $a2 $a2 1
lbu $a0 0($a2)
move $v0 $a0
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a2 8($sp)
addi $sp $sp 12
jr $ra
############################################################################



###################################################################################################################
###################################################################################################################
####### Fonctions permettant d'écrire un nouveau fichier BMP


#############################################################################
### Ecrire les entetes
# Entrées: $a0: descripteur de fichier
#	   $a1: adresse du premier octet de la matrice calculée
# Pré-conditions: 
# Sorties:
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
WriteOutput:
# prologue
subu $sp $sp 16
sw $v0 0($sp)
sw $a1 4($sp)
sw $a2 8($sp)
sw $ra 12($sp)
# corps
move $s1 $a1
# chargement des données nécessaires (largeur, hauteur, profondeur, resol vert & hor)
la $a1 bufLar
lw $t0 0($a1)
la $a1 bufHau
lw $t1 0($a1)
la $a1 bufPro
lw $t2 0($a1)
la $a1 bufRH
lw $t3 0($a1)
la $a1 bufRV
lw $t4 0($a1)
# on fait quelques calculs pour les données à écrire
li $t5 4
div $t0 $t5
mfhi $t6
add $t5 $t0 $t6
mul $t5 $t5 $t1
addi $t6 $t5 1078 # 62 = entetes + palette 2 couleurs
# on débute l'écriture
# on écrit la signature
la $a1 sign
li $a2 2
li $v0 15
syscall
# on écrit la taille totale
li $v0 15
la $a1 bufInt
sw $t6 0($a1)
li $a2 4
syscall
# champ réservé (0)
li $t6 0
sw $t6 0($a1)
li $v0 15
syscall
# offset
li $t6 1078
sw $t6 0($a1)
li $v0 15
syscall
# taille entete image
li $t6 40
sw $t6 0($a1)
li $v0 15
syscall
# largeur
sw $t0 0($a1)
li $v0 15
syscall
# hauteur
sw $t1 0($a1)
li $v0 15
syscall
# nombre de plans (1) et profondeur
li $t6 1
sh $t6 0($a1)
li $t6 8
sh $t6 2($a1)
li $v0 15
syscall
# méthode de compression
li $t6 0
sw $t6 0($a1)
li $v0 15
syscall
# taille image
sw $t5 0($a1)
li $v0 15
syscall
# résolution horizontale
sw $t3 0($a1)
li $v0 15
syscall
# résolution verticale
sw $t4 0($a1)
li $v0 15
syscall
# nb couleurs
li $t6 256
sw $t6 0($a1)
li $v0 15
syscall
# nb couleurs importantes
li $v0 15
syscall
# couleurs de la palette
li $t8 0
li $t7 256
BouclePalette:
move $t6 $t8
beq $t8 $t7 FinBouclePalette
sb $t6 0($a1)
sb $t6 1($a1)
sb $t6 2($a1)
li $t6 0
sb $t6 3($a1)
li $v0 15
syscall
addi $t8 $t8 1
j BouclePalette
FinBouclePalette:
# écriture de la matrice
lw $a1 4($sp) # on reprend l'adresse de la matrice dans $a1
move $a2 $t5 # nbr d'octets à écrire = taille de l'image
li $v0 15
syscall
# # test avec alternance noir/blanc (colonnes successives)
# move $t8 $t1
# BoucleHauteur:
# beqz $t8 FinBoucleHauteur
# move $t7 $t0
# BoucleLargeur:
# beqz $t7 FinBoucleLargeur
# li $v0 15
# li $t6 1
# sb $t6 0($a1)
# sb $t6 1($a1)
# sb $t6 2($a1)
# sb $t6 3($a1)
# syscall
# li $v0 15
# li $t6 0
# sw $t6 0($a1)
# syscall
# subu $t7 $t7 8
# j BoucleLargeur
# FinBoucleLargeur:
# subu $t8 $t8 1
# j BoucleHauteur
# FinBoucleHauteur:
# epilogue
lw $v0 0($sp)
lw $a1 4($sp)
lw $a2 8($sp)
lw $ra 12($sp)
addi $sp $sp 16
jr $ra
#############################################################################
# Entete du fichier:
# 	2o  BM
# 	4o  14 + 40 + 256 (nb couleur) * 4 + (largeur*pronfondeur/8)+((largeur*pronfondeur/8)%4)*hauteur
# 	4o  0
# 	4o  54 + 256 (nb couleur) * 4
# 
# Entete de l'image:
# 	4o  40
# 	4o  largeur
# 	4o  hauteur
# 	2o  1
# 	2o  8
# 	4o  0
# 	4o  (largeur*pronfondeur/8)+((largeur*pronfondeur/8)%4)*hauteur
# 	4o  resol hor / 0
# 	4o  resol ver / 0
# 	4o  256
# 	4o  256 / 0
# 	
# Palette:
# 	4o  0,0,0,0
#	4o  ...
# 	4o  255,255,255,0
# 	
# Matrice:
# 	matrice calculée
# 

############################################################################
### Lire la case i,j de la matrice envoyée en argument
# Entrées: $a0: matrice
#          $a1: la ligne i
#          $a2: la colonne j
# Pré-conditions: 
# Sorties: $v0: valeur mat[i][j]
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
GetElement:
# prologue
subu $sp $sp 12
sw $s0 0($sp)
sw $s1 4($sp)
sw $s2 8($sp)
# corps
move $s0 $a0 # adresse temporaire dans s0
la $s1 bufLar # on va récup la largeur
lw $s2 0($s1) # s2 = largeur en pixel
mul $s1 $s2 $a1 # s1 = largeur * i
add $s1 $s1 $a2 # s1 = s1 + j
add $s0 $s0 $s1 # s0 = s0 + s1
lbu $v0 0($s0) # on recupere la valeur contenue dans $s1 dans $v0 qui est mat[i][j]
# epilogue
lw $s0 0($sp)
lw $s1 4($sp)
lw $s2 8($sp)
addi $sp $sp 12
jr $ra
############################################################################

#############################################################################
### Modifier un élément d'une matrice
# Entrées: $a0: adresse de la matrice
#	   $a1: ligne i
#	   $a2: colonne j
#	   $a3: élément à écrire
# Pré-conditions: 
# Sorties:
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
SetElement:
# prologue
subu $sp $sp 12
sw $s0 0($sp)
sw $s1 4($sp)
sw $s2 8($sp)
# corps
move $s0 $a0 # adresse temporaire dans s0
la $s1 bufLar # on va récup la largeur
lw $s2 0($s1) # s2 = largeur en pixel
mul $s1 $s2 $a1 # s1 = largeur * i
add $s1 $s1 $a2 # s1 = s1 + j
add $s0 $s0 $s1 # s0 = s0 + s1
sb $a3 0($s0) # on écrit a3 (1 octet) à cette adresse
# epilogue
lw $s0 0($sp)
lw $s1 4($sp)
lw $s2 8($sp)
addi $sp $sp 12
jr $ra
#############################################################################

#############################################################################
### Calculer le gradient horizontal
# Entrées: $a0: adresse de la matrice A
#	   $a1: ligne i
#	   $a2: colonne j
# Pré-conditions: 
# Sorties: $v0: gradient
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
GradientX:
# prologue
subu $sp $sp 16
sw $s1 0($sp)
sw $a2 4($sp)
sw $ra 8($sp)
sw $a1 12($sp)
# corps
move $s1 $a1
# Formule : Gx(i,j) = A(i-1,j-1) - A(i-1,j+1) + 2*A(i,j-1) - 2*A(i,j+1) + A(i+1,j-1) - A(i+1,j+1)
subu $a1 $a1 1 # i-1
subu $a2 $a2 1 # j-1
jal GetElement
move $t0 $v0 # gradient = A(i-1,j-1)
addi $a2 $a2 2 # j+1
jal GetElement
sub $t0 $t0 $v0 # gradient = gradient - A(i-1,j+1)
addi $a1 $a1 1 # i
subu $a2 $a2 2 # j-1
jal GetElement
li $t1 2
mul $v0 $v0 $t1
add $t0 $t0 $v0 # gradient = gradient + 2*A(i,j-1)
addi $a2 $a2 2 # j+1
jal GetElement
mul $v0 $v0 $t1
sub $t0 $t0 $v0 # gradient = gradient - 2*A(i,j+1)
addi $a1 $a1 1 # i+1
subu $a2 $a2 2 # j-1
jal GetElement
add $t0 $t0 $v0 # gradient = gradient + A(i+1,j-1)
addi $a2 $a2 2 # j+1
jal GetElement
sub $t0 $t0 $v0 # gradient = gradient - A(i+1,j+1)
move $v0 $t0 # $v0 = gradient
move $a1 $s1
# epilogue
lw $s1 0($sp)
lw $a2 4($sp)
lw $ra 8($sp)
lw $a1 12($sp)
addi $sp $sp 16
jr $ra
#############################################################################

#############################################################################
### Calculer le gradient vertical
# Entrées: $a0: adresse de la matrice A
#	   $a1: ligne i
#	   $a2: colonne j
# Pré-conditions: 
# Sorties: $v0: gradient
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
GradientY:
# prologue
subu $sp $sp 16
sw $s1 0($sp)
sw $a2 4($sp)
sw $ra 8($sp)
sw $a1 12($sp)
# corps
move $s1 $a1
# Formule : Gy(i,j) = A(i-1,j-1) + 2*A(i-1,j) + A(i-1,j+1) - A(i+1,j-1) - 2*A(i+1,j) - A(i+1,j+1)
subu $a1 $a1 1 # i-1
subu $a2 $a2 1 # j-1
jal GetElement
move $t0 $v0 # gradient = A(i-1,j-1)
addi $a2 $a2 1 # j
jal GetElement
li $t1 2
mul $v0 $v0 $t1
add $t0 $t0 $v0 # gradient = gradient + 2*A(i-1,j)
addi $a2 $a2 1 # j+1
jal GetElement
add $t0 $t0 $v0 # gradient = gradient + A(i-1,j+1)
addi $a1 $a1 2 # i+1
subu $a2 $a2 2 # j-1
jal GetElement
subu $t0 $t0 $v0 # gradient = gradient - A(i+1,j-1)
addi $a2 $a2 1 # j
jal GetElement
mul $v0 $v0 $t1
subu $t0 $t0 $v0 # gradient = gradient - 2*A(i+1,j)
addi $a2 $a2 1 # j+1
jal GetElement
subu $t0 $t0 $v0 # gradient = gradient - A(i+1,j+1)
move $v0 $t0 # $v0 = gradient
move $a1 $s1
# epilogue
lw $s1 0($sp)
lw $a2 4($sp)
lw $ra 8($sp)
lw $a1 12($sp)
addi $sp $sp 16
jr $ra
#############################################################################

#############################################################################
### Calculer la matrice G (x ou y)
# Entrées: $a0: adresse de la matrice A
#	   $a1: adresse de la matrice Gx ou Gy
#	   $a2: seuil s
#	   $a3: 0 pour gradientX, gradientY sinon
# Pré-conditions: 
# Sorties:
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
CalculerGXY:
# prologue
subu $sp $sp 44
sw $a0 0($sp)
sw $a1 4($sp)
sw $a2 8($sp)
sw $a3 12($sp)
sw $s0 16($sp)
sw $s1 20($sp)
sw $s2 24($sp)
sw $v0 28($sp)
sw $ra 32($sp)
sw $s3 36($sp)
sw $s4 40($sp)
# corps
move $t6 $a2 # seuil s dans t6
li $t7 255 # seuil max dans t7
la $t0 bufHau
lw $s4 0($t0) # hauteur dans s4
la $t2 bufLar
lw $s3 0($t2) # largeur dans s3
subu $t8 $s4 1 # hauteur-1 dans t8
subu $t9 $s3 1 # largeur-1 dans t9
move $s0 $a0 # adresse A dans s0
move $s1 $a1 # adresse G (x ou y) dans s1
move $s2 $a3 # X ou Y dans s2
li $a1 0 # init
BoucleI:
beq $a1 $s4 FinBoucleI # si i = hauteur, break
li $a2 0 # init
BoucleJ:
beq $a2 $s3 FinBoucleJ # si j = largeur, break
beqz $a1 Zero # si i==0, set à 0
beqz $a2 Zero # si j==0, set à 0
beq $a1 $t8 Zero # si i==hauteur-1, set à 0
beq $a2 $t9 Zero # si j==largeur-1, set à 0
move $a0 $s0 # adresse de A dans a0, on va calculer le gradient
beqz $s2 X # si s2==0, gradientX
jal GradientY # sinon gradientY
j FinXY
X:
jal GradientX
j FinXY
FinXY:
bltz $v0 Absolue # si v0 est négatif, v0 = |v0|
VerifValeur:
bgt $v0 $t7 Max # si v0 supérieur à 255, v0=255
blt $v0 $t6 Zero # si v0 inférieur au seuil s, v0=0
move $a3 $v0 # on copie v0 dans a3 (arg pour SetElement)
j ContinueCGX # on continue
Absolue:
negu $v0 $v0
j VerifValeur # on repart vérifier si 0 <= v0 <= 255
Zero:
li $a3 0 # set à 0
j ContinueCGX # on continue
Max:
li $a3 255 # set à 255
j ContinueCGX # on continue
ContinueCGX:
move $a0 $s1 # adresse de Gx dans a0 (on va écrire dans Gx)
jal SetElement # on set l'élément (a1,a2) à a3
addi $a2 $a2 1 # on incrémente j
j BoucleJ # on boucle sur j
FinBoucleJ:
addi $a1 $a1 1 # on incrémente i
j BoucleI # on boucle sur i
FinBoucleI:
# epilogue
lw $a0 0($sp)
lw $a1 4($sp)
lw $a2 8($sp)
lw $a3 12($sp)
lw $s0 16($sp)
lw $s1 20($sp)
lw $s2 24($sp)
lw $v0 28($sp)
lw $ra 32($sp)
lw $s3 36($sp)
lw $s4 40($sp)
addi $sp $sp 44
jr $ra
#############################################################################

############################################################################
### Additionner deux matrices 
# Entrées: $a0: première matrice (modifiée par effet de bord)
#          $a1: deuxième matrice
#	   $a2: seuil s
# Pré-conditions: 
# Sorties:
# Post-conditions: les registres temporaires $si sont rétablis si utilisés
AddMatrices:
# prologue
subu $sp $sp 16
sw $ra 0($sp)
sw $a0 4($sp)
sw $a1 8($sp)
sw $a2 12($sp)
# corps
la $t9 bufLar #on recupere la largeur de la matrice
lw $t7 0($t9) #on la charge dans $t7
la $t8 bufHau #on recupere la hauteur de la matrice
lw $t6 0($t8) #on la charge dans t6
lw $t0 0($t8)
li $t4 255 # seuil max dans t4
move $t5 $a2 # seuil s dans t5
AddMatricesLoopI:
beq $t0 $0 AddMatricesEndLoop #si on a fait toutes les lignes on arrete
lw $t1 0($t9)                #on met la condition d'arret de la boucle pour les colonnes
        AddMatricesLoopJ:
        beq $t1 $0 EndLoopJ
        #on recupere déjà les elements de mat 1 et mat 2
        lw $a0 4($sp) #on passe l'adresse de la matrice 1
        move $a1 $t0 #la ligne 
        move $a2 $t1 #la colonne...
        jal GetElement
        
        move $t3 $v0 #on place le resultat dans $t3
        
        #on rappelle la fonction pour mat2
        lw $a0 8($sp) #on passe l'adresse de la matrice 1
        move $a1 $t0 #la ligne 
        move $a2 $t1 #la colonne...
        jal GetElement
        
        add $v0 $v0 $t3 #on fait la somme des deux cases recuperées
        blt $v0 $t5 SeuilInf
        bgt $v0 $t4 SeuilSup
        j ContinueAM
        SeuilInf:
        li $v0 0
        j ContinueAM
        SeuilSup:
        li $v0 255
        ContinueAM:
        lw $a0 4($sp) #on passe l'adresse de la matrice 1
        move $a1 $t0 #la ligne ou l'on veut modifier l'element
        move $a2 $t1 #la colonne...
        move $a3 $v0 #la somme des deux cases de mat1 et mat2
        jal SetElement
        subu $t1 $t1 1 #on passe a la colonne suivante
        j AddMatricesLoopJ
EndLoopJ:
subu $t0 $t0 1 #on passe a la ligne suivant car on a fait toutes les colonnes de la ligne
j AddMatricesLoopI
AddMatricesEndLoop:
# epilogue
lw $ra 0($sp)
lw $a0 4($sp)
lw $a1 8($sp)
lw $a2 12($sp)
addi $sp $sp 16
jr $ra
############################################################################
