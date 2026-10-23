# Dieta: cadastro manual e scanner

Type: task
Status: resolved
Blocked by: 28

## Question

Portar o `AddManualFoodPage.tsx` (Nome/Porção/Calorias/macros como valores da porção, normalizados pra 100 g antes do `POST /foods/custom`, unidade opcional que vira `servingLabel`/`servingGrams`) e o scanner nativo: `DataScannerViewController` restrito a EAN-13/EAN-8/UPC-A/UPC-E, checando `isSupported`/`isAvailable`, `NSCameraUsageDescription` no Info.plist extra, `GET /foods/barcode/:code`, 404 → cadastro manual pré-preenchido com o código. Antes de começar, confirmar que o VisionKit não depende de ferramenta exclusiva do Xcode. `parsePortionGrams` e a normalização vão pro Kit com teste. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** Linhas 16–18 e 20 do checklist da Fase D conferidas. A 21 ficou parcial: um produto conhecido abriu o QuantitySheet. As linhas 19 e 22, o resto da 21 e o rótulo do botão de voltar ficaram pro [Uso real da Fase D](32-uso-real-fase-d.md).

- **Backend (decisão do usuário: corrigir o vínculo do código)**: o `externalId` que a web manda depois de um 404 do scanner era gravado e nunca lido. O `findByBarcode` só procurava `source: OFF`, então o mesmo código dava 404 de novo. E um segundo cadastro com o mesmo código batia no `@@unique([source, externalId])` global e devolvia 500, mesmo entre usuários diferentes. Correção:
  - o `findByBarcode` procura primeiro o alimento CUSTOM do próprio usuário ligado ao código;
  - o `createCustom` devolve o alimento do próprio usuário quando o código já é dele, e grava sem vínculo quando o código é de outro usuário (`P2002` só é engolido quando há `externalId`).
  
  Sem migration. 4 testes novos, 598 passando. **Pendente**: deploy do backend no Render. A web não muda, e o comentário dela passou a ser verdade.
- **Kit** (`DietManualFood.swift`, 13 testes, 281 no total): `ManualFoodDraft`, que porta o `parsePortionGrams`, a normalização pra 100 g e o par unidade/porção. Diferente da web, aceita vírgula decimal ("37,5 g", "7,5"). `CreateCustomFoodRequest` omite os campos nil. `ProductBarcode` confere o dígito verificador GS1 (o UPC-E é aceito só pelo tamanho).
- **App**:
  - Botão de scanner ao lado da busca e link "Não encontrou? Adicionar manualmente →".
  - `ManualFoodView` empilhada na navegação, com o unit picker em `Menu` e "OK" acima do teclado numérico.
  - `BarcodeScannerView` em `fullScreenCover` escuro, com moldura mostarda, entorno escurecido em quatro faixas, vibração ao ler, "Abrir Ajustes" com a câmera negada e "Tentar novamente" quando a busca falha.
  - O produto encontrado abre o QuantitySheet, e o 404 abre o cadastro já com o código. As duas ações só acontecem no `onDismiss` do cover.
  - O alimento criado abre o QuantitySheet.
  - O `NSCameraUsageDescription` está só em PT.
  - Strings PT/EN `diet.manual.*`/`diet.scanner.*`.
- **VisionKit**: o `DataScannerViewController` compila e roda com o xtool, sem nada exclusivo do Xcode.
- **Corrigido na validação**:
  - o link estava em `accTx` e passou pra `acc`, como na web;
  - o voltar do cadastro dizia "Back", e o Adicionar ganhou `navigationTitle`;
  - o foco automático escondia o botão atrás do teclado e foi tirado, como na web;
  - o teclado numérico não fechava e ganhou o "OK";
  - o escurecimento por máscara virou quatro faixas.
- **Desvios aceitos**: o voltar nativo no lugar do "← Voltar à busca" da web, e o botão "Adicionar alimento" desabilitado enquanto falta campo, no lugar da validação `required` do navegador.

