{{flutter_js}}
{{flutter_build_config}}

const statusElement = document.getElementById('loading-status');

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      if (statusElement) {
        statusElement.textContent = 'Carregando o aplicativo...';
      }

      const appRunner = await engineInitializer.initializeEngine();

      if (statusElement) {
        statusElement.textContent = 'Quase pronto...';
      }

      await appRunner.runApp();
      document.getElementById('loading')?.remove();
    } catch (error) {
      if (statusElement) {
        statusElement.textContent =
          'Nao foi possivel iniciar. Verifique sua conexao.';
      }
      console.error('Falha ao iniciar o Flutter:', error);
    }
  },
});
