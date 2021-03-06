{% from "openssh/map.jinja" import openssh with context %}

include:
  - openssh

{% if salt['pillar.get']('sshd_config', False) %}
sshd_config:
  file.managed:
    - name: {{ openssh.sshd_config }}
    - source: {{ openssh.sshd_config_src }}
    - template: jinja
    - user: {{ openssh.sshd_config_user }}
    - group: {{ openssh.sshd_config_group }}
    - mode: {{ openssh.sshd_config_mode }}
    - watch_in:
      - service: {{ openssh.service }}
{% endif %}

{% if salt['pillar.get']('ssh_config', False) %}
ssh_config:
  file.managed:
    - name: {{ openssh.ssh_config }}
    - source: {{ openssh.ssh_config_src }}
    - template: jinja
    - user: {{ openssh.ssh_config_user }}
    - group: {{ openssh.ssh_config_group }}
    - mode: {{ openssh.ssh_config_mode }}
{% endif %}

{%- for keyType in ['ecdsa', 'dsa', 'rsa', 'ed25519'] %}
{%-   set keyFile = "/etc/ssh/ssh_host_" ~ keyType ~ "_key" %}
{%-   set keySize = salt['pillar.get']('openssh:generate_' ~ keyType ~ '_size', False) %}
{%-   if salt['pillar.get']('openssh:generate_' ~ keyType ~ '_keys', False) %}
{%-     if keySize and salt['pillar.get']('openssh:enforce_' ~ keyType ~ '_size', False) %}
ssh_remove_short_{{ keyType }}_key:
  cmd.run:
    - name: "rm -f {{ keyFile }} {{ keyFile }}.pub"
    - onlyif: "test -f {{ keyFile }}.pub && test `ssh-keygen -l -f {{ keyFile }}.pub 2>/dev/null | awk '{print $1}'` -lt {{ keySize }}"
    - require_in:
        - cmd: ssh_generate_host_{{ keyType }}_key
{%-     endif %}
ssh_generate_host_{{ keyType }}_key:
  cmd.run:
    {%- if keySize %}
    - name: ssh-keygen -t {{ keyType }} -b {{ keySize }} -N '' -f {{ keyFile }}
    {%- else %}
    - name: ssh-keygen -t {{ keyType }} -N '' -f {{ keyFile }}
    {%- endif %}
    - creates: {{ keyFile }}
    - user: root
    - watch_in:
      - service: {{ openssh.service }}

{%-   elif salt['pillar.get']('openssh:absent_' ~ keyType ~ '_keys', False) %}
ssh_host_{{ keyType }}_key:
  file.absent:
    - name: {{ keyFile }}
    - watch_in:
      - service: {{ openssh.service }}

ssh_host_{{ keyType }}_key.pub:
  file.absent:
    - name: {{ keyFile }}.pub
    - watch_in:
      - service: {{ openssh.service }}

{%-   elif salt['pillar.get']('openssh:provide_' ~ keyType ~ '_keys', False) %}
ssh_host_{{ keyType }}_key:
  file.managed:
    - name: {{ keyFile }}
    - contents_pillar: 'openssh:{{ keyType }}:private_key'
    - user: root
    - mode: 600
    - watch_in:
      - service: {{ openssh.service }}

ssh_host_{{ keyType }}_key.pub:
  file.managed:
    - name: {{ keyFile }}.pub
    - contents_pillar: 'openssh:{{ keyType }}:public_key'
    - user: root
    - mode: 600
    - watch_in:
      - service: {{ openssh.service }}
{%-   endif %}
{%- endfor %}
