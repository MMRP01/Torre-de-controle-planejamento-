# Colocando a ferramenta online, com vários usuários em tempo real

A tela da ferramenta fica no **GitHub Pages**. Os dados, o login e o tempo real ficam no **Supabase** (um serviço
de banco de dados com plano gratuito). Cada pessoa entra com o próprio e-mail e senha, e o que uma pessoa altera
aparece para as outras em poucos segundos, sem recarregar a página.

Tempo estimado: 20 a 30 minutos. Você precisa de uma conta no GitHub e uma no Supabase.

---

## 1. Criar o projeto no Supabase
1. Acesse **supabase.com** → *Start your project* → entre (pode usar a conta do GitHub).
2. **New project**. Dê um nome (ex.: `producao-menzoil`), escolha uma **senha do banco** (guarde-a) e a região
   **South America (São Paulo)** (os dados ficam no Brasil e a resposta é mais rápida).
3. Aguarde 1 a 2 minutos até o projeto ficar pronto.

## 2. Criar as tabelas e as regras de segurança
1. No painel do projeto: **SQL Editor** → **New query**.
2. Abra o arquivo `supabase/schema.sql` deste pacote, copie **tudo**, cole no editor e clique **Run**.
3. Deve aparecer *Success. No rows returned*. (Pode rodar de novo quando atualizar a ferramenta: é seguro.)

## 3. Ajustar o login
1. **Authentication → Providers → Email**: deixe **Email** habilitado.
2. Para uso interno, **desmarque "Confirm email"**. Assim, quem cria a conta entra direto (depois o administrador libera).
   Se deixar marcado, cada pessoa terá de clicar em um link recebido por e-mail, e o plano gratuito envia poucas
   mensagens por hora.
3. **Authentication → URL Configuration → Site URL**: coloque o endereço onde a ferramenta vai ficar
   (ex.: `https://SEU-USUARIO.github.io/planejamento-producao/`). É para onde levam os links de "Esqueci a senha".

## 4. Conferir o tempo real
O `schema.sql` já liga o tempo real nas tabelas certas. Para conferir: **Database → Publications →
supabase_realtime** deve listar as tabelas `registros` e `perfis`. (Depois você também confere pelo botão
"Testar conexão" da ferramenta.)

## 5. Copiar a URL e a chave
**Project Settings → API**:
- **Project URL** (ex.: `https://abcdefghijkl.supabase.co`)
- **Project API keys → `anon` `public`** (uma chave longa que começa com `eyJ…`)

Abra o arquivo **`config.js`** e preencha:
```js
window.MENZOIL_CONFIG = {
  supabaseUrl: 'https://abcdefghijkl.supabase.co',
  supabaseAnonKey: 'eyJhbGciOi...'
};
```
> A chave `anon` é pública por desenho — pode ir para o GitHub. **Nunca** use a chave `service_role` aqui.

## 6. Publicar no GitHub Pages
1. Crie um repositório no GitHub e suba os arquivos: `index.html`, `config.js`, `README.md`, `.nojekyll`
   (e, se quiser guardar, as pastas `supabase/` e `docs/`).
2. **Settings → Pages → Deploy from a branch → `main` / (root)**. Em cerca de 1 minuto o site abre.
3. Domínio próprio (opcional): *Settings → Pages → Custom domain* + um registro CNAME no seu provedor de DNS.
   Depois, atualize o **Site URL** do passo 3.3.

## 7. Primeiro acesso — faça logo, antes de divulgar o endereço
1. Abra o site → **Criar conta** (seu nome, e-mail e senha).
2. **A primeira conta criada vira administradora automaticamente.** Por isso crie a sua *antes* de passar o endereço
   para outras pessoas.
3. Entre em **Usuários e Permissões → 🩺 Testar conexão**. Todos os passos devem ficar com ✓. Se algum falhar, a
   própria tela diz o que fazer (e a tabela "Problemas comuns", abaixo, também).

## 8. Colocar os dados no servidor (uma vez)
Escolha uma das opções:
- **A) Enviar o arquivo completo (recomendado se você usa a versão com os dados embutidos).** Copie o seu `config.js`
  preenchido para a mesma pasta do `index.html` **completo** (o privado), abra-o no navegador e entre como
  administrador. Como o servidor está vazio, a ferramenta pergunta *"Enviar esses dados ao servidor?"* → Confirmar.
  Itens, receitas, pedidos e recursos sobem em alguns segundos.
- **B) Importar planilhas** pelo site (Importação de Dados) e cadastrar os recursos (Cadastros → Recursos & Capacidade).
- **C) Restaurar um backup (.json)** em Importação de Dados.

Só depois do passo 7 (administrador criado) as outras pessoas podem usar.

## 9. Adicionar as pessoas
1. A pessoa abre o endereço e clica em **Criar conta**.
2. A conta aparece na hora em *Usuários e Permissões*, como **⏳ Aguardando liberação**.
3. Você clica **Liberar** e define o que ela vê e edita (por tela, por campo e, se quiser, **trava de filtros**).
4. Alterações de permissão chegam à pessoa **ao vivo**. **Desativar** derruba a sessão dela na hora.

---

## Como o trabalho simultâneo funciona
- Cada alteração é enviada ao servidor em segundos e aparece nas outras telas abertas. Quem está digitando não é
  interrompido: a tela dele só atualiza quando ele sai do campo.
- Duas pessoas mexendo em **campos diferentes** do mesmo registro: as duas alterações valem. No **mesmo campo**: vale a
  última gravação.
- Sem internet: o indicador mostra "⚠ Sem conexão — N alteração(ões) aguardando". Ao voltar, a ferramenta envia o que
  ficou pendente e baixa o que perdeu.
- O servidor **recusa** gravação de quem só tem leitura e de quem tenta mudar a programação de uma linha que já tem
  produção (só administrador). Nesses casos a tela volta ao valor correto e avisa.
- **Gerar plano** é uma ação que mexe em muitas linhas: evite que duas pessoas gerem o plano ao mesmo tempo.

## Problemas comuns
| O que aparece | Causa provável | O que fazer |
|---|---|---|
| "Não foi possível carregar a biblioteca do Supabase" | Sem internet, bloqueio de rede, ou o endereço da biblioteca mudou | Teste outra rede. Se persistir, veja a seção "Biblioteca do Supabase" abaixo |
| Tela de login pede e-mail, mas nada acontece | `config.js` em branco ou com a URL errada | Confira a URL e a chave `anon` no passo 5 |
| "Não foi possível ler os dados" no teste | O `schema.sql` não foi executado por inteiro, ou URL/chave de outro projeto | Rode o `schema.sql` de novo; confira o `config.js` |
| "Tempo real" falha no teste | Tabelas fora da publicação, ou rede da empresa bloqueia WebSocket | Passo 4; teste em outra rede (celular) |
| Conta criada, mas "Aguardando liberação" | É o esperado | O administrador libera em Usuários e Permissões |
| "Confirme o e-mail primeiro" | "Confirm email" está ligado | Passo 3.2 (ou clique no link do e-mail) |
| Link de "Esqueci a senha" abre página errada | Site URL incorreto | Passo 3.3 |
| Não deixa rebaixar um administrador | Regra de segurança: sempre deve existir um administrador ativo | Promova outro antes |
| Projeto "pausado" | Plano gratuito pausa após cerca de 1 semana sem uso | No painel do Supabase, clique em *Restore project* |

## Biblioteca do Supabase
A ferramenta carrega a biblioteca do Supabase (`supabase-js`, versão fixa) de um CDN público (jsDelivr). Se esse endereço
não carregar na sua rede, baixe o arquivo da biblioteca (o pacote `@supabase/supabase-js`, arquivo `dist/umd/supabase.js`),
salve-o na mesma pasta como `supabase.js` e, no `index.html`, acrescente a linha
`<script src="supabase.js"></script>` **antes** de `<script src="config.js"></script>`. A ferramenta usa a biblioteca já
carregada e não tenta buscá-la no CDN.

## Backup, custo e segurança
- **Backup:** no plano gratuito não há backup automático com retorno no tempo. Use **Importação de Dados →
  Exportar backup** com frequência e guarde o arquivo **fora do GitHub** (tem dados reais).
- **Custo:** o plano gratuito atende bem uma equipe pequena. Confira os limites atuais (armazenamento, conexões
  simultâneas, e-mails por hora) no site do Supabase. Para mais pessoas ou mais garantias, existem planos pagos.
- **Segurança:** só quem está logado **e ativo** lê os dados; ninguém grava direto nas tabelas (só pela função do
  servidor, que confere permissão, versão e a trava de linha produzida). Campos por tela e travas de filtro organizam
  o uso; o servidor garante, no mínimo, que quem só consulta nunca grava.
- **LGPD:** os dados ficam no Supabase, na região que você escolheu. Trate o acesso ao painel do Supabase e à senha
  do banco como confidenciais.
