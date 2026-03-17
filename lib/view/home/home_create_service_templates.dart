part of '../homescreen.dart';

typedef _CreateServiceTemplate = ({String label, String name, String image, int port});

const List<_CreateServiceTemplate> _createServiceTemplates = [
  (label: 'Test (nginx)', name: 'sovereignd-test', image: 'nginx:alpine', port: 80),
  (label: 'Vaultwarden', name: 'vaultwarden', image: 'vaultwarden/server:latest', port: 80),
  (label: 'Jellyfin', name: 'jellyfin', image: 'jellyfin/jellyfin:latest', port: 8096),
  (label: 'Navidrome', name: 'navidrome', image: 'deluan/navidrome:latest', port: 4533),
  (label: 'Minecraft', name: 'minecraft', image: 'itzg/minecraft-server:latest', port: 25565),
  (label: 'Uptime Kuma', name: 'uptime-kuma', image: 'louislam/uptime-kuma:latest', port: 3001),
  (label: 'Nextcloud (Drive Alternative)', name: 'nextcloud', image: 'nextcloud:latest', port: 80),
  (label: 'Immich (Photos Alternative)', name: 'immich-server', image: 'ghcr.io/immich-app/immich-server:release', port: 2283),
  (label: 'Outline (Docs/Notion Alternative)', name: 'outline', image: 'outlinewiki/outline:latest', port: 3000),
  (label: 'Umami (Analytics Alternative)', name: 'umami', image: 'ghcr.io/umami-software/umami:latest', port: 3000),
  (label: 'Whoogle (Private Search)', name: 'whoogle', image: 'benbusby/whoogle-search:latest', port: 5000),
  (label: 'Element (Matrix Client)', name: 'element', image: 'tiredofit/element:0.6.59', port: 80),
  (label: 'Focalboard (Project Management)', name: 'focalboard', image: 'mattermost/focalboard:latest', port: 8000),
  (label: 'Mattermost (Chat Alternative)', name: 'mattermost', image: 'mattermost/mattermost-team-edition:latest', port: 8065),
  (label: 'Gitea (Git Server)', name: 'gitea', image: 'gitea/gitea:latest', port: 3000),
  (label: 'NocoDB (Airtable Alternative)', name: 'nocodb', image: 'nocodb/nocodb:latest', port: 8080),
  (label: 'Adminer (Database Viewer)', name: 'adminer', image: 'adminer:latest', port: 8080),
  (label: 'Grafana (Metrics Dashboard)', name: 'grafana', image: 'grafana/grafana:latest', port: 3000),
];
