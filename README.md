# PKA - Busca de instâncias

Automação de busca de instâncias para PokeAlliance em AutoHotkey v2 no Windows.

## Uso

1. Baixe `PKA-Busca-Instancias.exe` na seção **Releases**.
2. Abra o PokeAlliance, informe o nome do personagem e, quando o nome estiver visível, clique em **Calibrar**. A posição fica salva no computador.
3. Pressione **F12** para iniciar ou parar. O programa procura instâncias com `0 jogadores`, tenta entrar e apita três vezes.
4. A opção de busca com o PKA coberto por outras janelas vem ligada. O jogo pode ficar atrás de outras janelas, mas não minimizado.

A busca percorre sete passos de rolagem por direção. A interface pode ser minimizada na bandeja.

## Atualizações

O executável verifica a versão mais recente no GitHub ao abrir. Quando há uma versão nova, pede confirmação, baixa o novo executável, confere o SHA-256 publicado pelo GitHub, substitui o arquivo atual e reinicia. As configurações do personagem e da calibração ficam em `%APPDATA%\PKA-Automacao\config.ini`.

Versões distribuídas antes de `v1.0.0` não contêm o atualizador e precisam ser substituídas manualmente uma vez. Para que versões futuras sejam encontradas, publique uma **Release** com tag `vX.Y.Z` e o anexo com o nome exato `PKA-Busca-Instancias.exe`.

## Compilar

Mantenha os arquivos desta pasta juntos e compile `PKA-Busca-Instancias.ahk` com AutoHotkey v2 / Ahk2Exe, usando a base de 64 bits. O `.exe` incorpora `0-jogador.png`, `wincapture.dll` e `pka-update.ps1`.

`wincapture.ahk` e `wincapture.dll` pertencem à biblioteca [ahk2_lib](https://github.com/thqby/ahk2_lib/tree/master/wincapture) de thqby. Consulte `wincapture-LICENSE.txt` para a licença MIT dessa dependência.

O jogo e a captura em segundo plano não foram testados em todos os computadores; a entrada em segundo plano pode exigir que o PKA venha à frente no clique final.
