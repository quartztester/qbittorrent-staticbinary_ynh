## Pont I2P / SAM

Le trafic torrent est confié à votre routeur I2P via le pont SAM, qui doit
être démarré et à l'écoute. Ce paquet n'installe **pas** de routeur I2P —
il attend l'une des applications YunoHost `java_i2p` / `i2pd` pour fournir
SAM. Les deux activent SAM par défaut sur des ports distincts en boucle
locale : `java_i2p` sur `127.0.0.1:7656` (valeur amont), `i2pd` sur
`127.0.0.1:7666`. Réglez `i2p_sam_port` sur le routeur utilisé.

Seuls les torrents dont le tracker/peer est une adresse I2P `*.i2p`
fonctionnent via I2P ; les torrents clearnet ne sont pas affectés (et
masqués quand le mode anonyme est actif).

Vérifiez que le pont est actif : `ss -ltn | grep -E ':7656|:7666'` — et que
qBittorrent y tient une session : `ss -tnp | grep qbittorrent`.

## Connexion de la stack *arr (Prowlarr/Sonarr/Radarr)

Ajoutez un client de téléchargement qBittorrent pointant vers l'URL
interne en boucle locale :

```
Host: 127.0.0.1      Port: <le réglage 'port' de l'app>   WebUI: /
Username: admin      Password: voir ci-dessous
```

Les connexions localhost ignorent le login web (sémantique qBittorrent
5.x : `WebUI\LocalHostAuth=false` dans la conf générée active l'exemption
de boucle locale). Les identifiants ci-dessous restent valides et vous
couvrent si vous modifiez ce réglage dans les options de sécurité du WebUI.

- Mot de passe : `yunohost app setting qbittorrent_static webui_password`
- Port :          `yunohost app setting qbittorrent_static port`

## Modifier les réglages I2P / anonymat

Le fichier de conf qBittorrent est entièrement géré : il est re-généré
depuis les réglages de l'application pendant que le service est arrêté.
Modifiez les réglages, puis ré-appliquez en relançant les scripts du
paquet :

```
yunohost app setting qbittorrent_static i2p_sam_port -v 7666
yunohost app setting qbittorrent_static anonymous -v true
yunohost app upgrade qbittorrent_static \
    -u https://github.com/quartztester/qbittorrent-staticbinary_ynh \
    --no-safety-backup --force
```

Ne modifiez **pas** le fichier de conf pendant que le service tourne —
qBittorrent réécrit sa propre conf à l'extinction et écraserait votre
édition comme la re-génération. (Pour un simple coup d'œil :
`yunohost app shell qbittorrent_static` ouvre un shell interactif avec les
helpers chargés.)

## Mettre à jour la version du binaire

Ce paquet épingle une version précise de
[qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static).
Les mises à jour sont manuelles : modifiez `version`, `url` et `sha256`
dans `manifest.toml`, puis `yunohost app upgrade`.
