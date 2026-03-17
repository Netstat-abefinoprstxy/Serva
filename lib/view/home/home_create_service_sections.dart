part of '../homescreen.dart';

extension _CreateServiceSheetStateSections on _CreateServiceSheetState {
  Widget _buildTemplatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Template', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedTemplate,
          items: [
            for (var i = 0; i < _createServiceTemplates.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(_createServiceTemplates[i].label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedTemplate = value;
              _applyTemplate(value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildBasicsForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. jellyfin-1234',
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _imageCtrl,
            decoration: const InputDecoration(
              labelText: 'Image',
              hintText: 'e.g. nginx:alpine  (or paste: docker pull grafana/grafana)',
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Image is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _portCtrl,
            decoration: const InputDecoration(
              labelText: 'Container port',
              hintText: 'e.g. 80',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              final raw = value?.trim();
              if (raw == null || raw.isEmpty) return 'Port is required';
              final parsed = int.tryParse(raw);
              if (parsed == null || parsed <= 0 || parsed > 65535) {
                return 'Port must be 1-65535';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavedMountsList() {
    if (_mounts.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mounts.length,
        itemBuilder: (context, index) {
          final mount = _mounts[index];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${mount.source} -> ${mount.target}'),
            subtitle: Text(
              '${mount.type}${mount.readOnly ? ' • read-only' : ''}${mount.managed ? ' • managed' : ''}',
            ),
            trailing: IconButton(
              tooltip: 'Remove mount',
              onPressed: () => _removeMount(index),
              icon: const Icon(Icons.close),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMountDraftForm() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _mountType,
          decoration: const InputDecoration(labelText: 'Mount type'),
          items: const [
            DropdownMenuItem(value: 'bind', child: Text('Host path bind')),
            DropdownMenuItem(value: 'volume', child: Text('Docker volume')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _mountType = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _mountSourceCtrl,
          decoration: InputDecoration(
            labelText: _mountType == 'bind' ? 'Source path' : 'Volume name',
            hintText: _mountType == 'bind'
                ? r'e.g. C:\Users\you\Documents\Serva\vaultwarden'
                : 'e.g. serva-vaultwarden-data',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _mountTargetCtrl,
          decoration: const InputDecoration(
            labelText: 'Container target',
            hintText: 'e.g. /data',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Read-only'),
          value: _mountReadOnly,
          onChanged: (value) {
            setState(() {
              _mountReadOnly = value;
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Managed by Serva'),
          subtitle: const Text('Marks this mount as part of the durable service definition.'),
          value: _mountManaged,
          onChanged: (value) {
            setState(() {
              _mountManaged = value;
            });
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addMount,
            icon: const Icon(Icons.add_link),
            label: const Text('Add mount'),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _createTest,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Create test'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _createService,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ),
      ],
    );
  }
}
