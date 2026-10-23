# Dieta: cadastro manual e scanner

Type: task
Status: open
Blocked by: 28

## Question

Portar o `AddManualFoodPage.tsx` (Nome/Porção/Calorias/macros como valores da porção, normalizados pra 100 g antes do `POST /foods/custom`, unidade opcional que vira `servingLabel`/`servingGrams`) e o scanner nativo: `DataScannerViewController` restrito a EAN-13/EAN-8/UPC-A/UPC-E, checando `isSupported`/`isAvailable`, `NSCameraUsageDescription` no Info.plist extra, `GET /foods/barcode/:code`, 404 → cadastro manual pré-preenchido com o código. Antes de começar, confirmar que o VisionKit não depende de ferramenta exclusiva do Xcode. `parsePortionGrams` e a normalização vão pro Kit com teste. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).
