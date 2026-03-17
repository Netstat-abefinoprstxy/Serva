part of '../template_gallery_screen.dart';

Future<void> _openInfiniteTemplates(BuildContext context) async {
  final uri = Uri.parse('https://hub.docker.com/search');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Docker Hub')),
    );
  }
}

Future<void> _pasteImageOrCommand(BuildContext context) async {
  final bloc = context.read<MainBloc>();
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  final image = _extractImageFromPaste(text);

  if (image == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clipboard does not look like an image or docker pull command.'),
      ),
    );
    return;
  }

  final launchConfig = await _showCustomImageLaunchFlow(
    context,
    image: image,
    suggestedName: _suggestNameFromImage(image),
  );
  if (launchConfig == null || !context.mounted) return;

  _registerCustomTemplate(_customTemplateFromImage(image));

  bloc.add(
    MainCreateServiceRequested(
      name: launchConfig.serviceName,
      image: image,
      containerPort: 80,
      mounts: launchConfig.mounts,
      env: launchConfig.env,
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Creating ${launchConfig.serviceName} from clipboard image...'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
