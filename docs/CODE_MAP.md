# Mapa de Código (generado)

> Archivo generado por `node scripts/gen_code_map.js`. No lo edites a mano.
> Regenerar tras tocar `lib/` o `test/`: `node scripts/gen_code_map.js`.
> El hook de pre-commit lo actualiza y lo añade al commit.

## Resumen

| Capa | Archivos | Líneas |
|---|---|---|
| `core/` | 8 | 958 |
| `data/` | 12 | 5310 |
| `domain/` | 11 | 2355 |
| `providers/` | 4 | 2198 |
| `services/` | 19 | 7850 |
| `ui/` | 31 | 22445 |
| `(raiz)/` | 2 | 106 |
| **Total** | **87** | **41222** |

## core/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/core/constants/app_colors.dart` | 69 | `AppColors` | `app_colors_budget_progress_test.dart`, `chat_screen_test.dart`, `dashboard_category_budget_test.dart`, +7 |
| `lib/core/constants/app_constants.dart` | 270 | `AppConstants` | `categoria_model_test.dart`, `gasto_provider_rate_cache_test.dart`, `settings_provider_notifications_test.dart`, +12 |
| `lib/core/theme/app_theme.dart` | 168 | `AppTheme` | - |
| `lib/core/utils/amount_parser.dart` | 98 | - | `amount_parser_test.dart` |
| `lib/core/utils/currency_formatter.dart` | 182 | `CurrencyFormatter` | `analysis_screen_redesign_test.dart`, `dashboard_category_budget_test.dart`, `category_chart_test.dart`, +1 |
| `lib/core/utils/date_formatter.dart` | 35 | `DateFormatter` | `analysis_screen_redesign_test.dart`, `smart_empty_state_and_lifecycle_test.dart` |
| `lib/core/utils/image_hash_service.dart` | 123 | `ImageHashService` | `image_hash_service_test.dart` |
| `lib/core/utils/uuid_generator.dart` | 13 | `UuidGenerator` | `uuid_generator_test.dart` |

## data/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/data/datasources/local/database_helper.dart` | 2400 | `UnitPriceRef`, `PriceHistory`, `DatabaseHelper` | `database_helper_batch_and_async_test.dart`, `database_helper_category_test.dart`, `database_helper_fts_test.dart`, +37 |
| `lib/data/datasources/remote/firestore_gastos_remote_data_source.dart` | 74 | `FirestoreGastosRemoteDataSource` | - |
| `lib/data/datasources/remote/gastos_remote_data_source.dart` | 26 | `RemoteGasto`, `RemotePresupuesto`, `GastosRemoteDataSource` | `reparar_tasas_dry_run_test.dart`, `sync_orchestration_test.dart` |
| `lib/data/datasources/remote/gemini_service.dart` | 746 | `VoiceOfflineException`, `VoiceServiceException`, `GeminiService` | `database_helper_batch_and_async_test.dart`, `chat_screen_test.dart`, `dashboard_screen_test.dart`, +4 |
| `lib/data/models/categoria_model.dart` | 69 | `CategoriaModel`, `CategoryModel` | `database_helper_category_test.dart`, `categoria_model_test.dart` |
| `lib/data/models/gasto_firestore_mapper.dart` | 77 | `GastoFirestoreMapper` | `gasto_firestore_mapper_test.dart` |
| `lib/data/models/gasto_model.dart` | 215 | `GastoModel` | `database_helper_batch_and_async_test.dart`, `database_helper_in_memory_harness_test.dart`, `contenido_negocio_identico_test.dart`, +35 |
| `lib/data/models/gemini_extraction_result.dart` | 1058 | `IvaModo`, `TipoLineaExtraccion`, `GeminiExtractionResult` | `fiscal_reconciliation_helper_test.dart`, `gemini_extraction_result_test.dart`, `scan_queue_provider_test.dart`, +5 |
| `lib/data/models/item_gasto_model.dart` | 276 | `OrigenCategoria`, `OrigenAlicuota`, `ItemGastoModel` | `database_helper_in_memory_harness_test.dart`, `database_helper_price_history_test.dart`, `fiscal_reconciliation_helper_test.dart`, +22 |
| `lib/data/models/presupuesto_remoto_model.dart` | 75 | `PresupuestoRemotoModel` | `presupuesto_remoto_model_test.dart`, `sync_orchestration_test.dart` |
| `lib/data/models/shopping_item_model.dart` | 53 | `ShoppingItemModel` | `shopping_item_model_test.dart`, `scan_queue_provider_test.dart`, `chat_screen_test.dart`, +2 |
| `lib/data/repositories/gasto_repository.dart` | 241 | `GastoRepository` | `database_helper_batch_and_async_test.dart`, `gasto_provider_monetary_summary_test.dart`, `gasto_provider_rate_cache_test.dart`, +7 |

## domain/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/domain/diagnostics/rm03_copy_strategy.dart` | 108 | `Rm03DiagnosticIoException`, `Rm03CopyStrategy`, `FileRm03CopyStrategy` | `rm03_diagnostic_protocol_test.dart` |
| `lib/domain/diagnostics/rm03_diagnostic_protocol.dart` | 710 | `Rm03DiagnosticSecurityException`, `Rm03DiagnosticSchemaException`, `Rm03QueryResult`, `Rm03DiagnosticReport`, +1 | `rm03_diagnostic_protocol_test.dart` |
| `lib/domain/finance/fiscal_reconciliation_helper.dart` | 539 | `SesionFiscalInicial`, `SugerenciaCorreccionFiscal`, `EstadoReconciliacionFiscal`, `FiscalReconciliationHelper` | `fiscal_reconciliation_helper_test.dart` |
| `lib/domain/finance/savings_health_calculator.dart` | 54 | `SavingsHealthCalculator` | `savings_health_calculator_test.dart`, `chat_context_etapa0_test.dart` |
| `lib/domain/finance/savings_health_models.dart` | 47 | `SavingsGoalStatus`, `SavingsHealthSnapshot` | `savings_health_calculator_test.dart` |
| `lib/domain/monetary/expense_tuple.dart` | 347 | `ExpenseTuple`, `TupleFailureCode`, `TupleBuildResult`, `TupleBuildSuccess`, +1 | `build_new_expense_tuple_test.dart` |
| `lib/domain/monetary/metodo_liquidacion.dart` | 12 | `MetodoLiquidacion` | `build_new_expense_tuple_test.dart` |
| `lib/domain/monetary/monetary_resolution.dart` | 246 | `EstadoValorMonetario`, `EstadoTasaPersistida`, `ValorMonetarioResuelto` | `contenido_negocio_identico_test.dart`, `resolve_persisted_expense_test.dart` |
| `lib/domain/monetary/rate_market.dart` | 85 | `RateMarket`, `EstadoTasaMoneda`, `RateSourceId` | `build_new_expense_tuple_test.dart`, `rate_market_test.dart`, `rate_quote_input_test.dart`, +1 |
| `lib/domain/monetary/rate_quote_input.dart` | 129 | `QuoteValidationError`, `RateQuoteInput` | `build_new_expense_tuple_test.dart`, `rate_quote_input_test.dart` |
| `lib/domain/monetary/resumen_lente_monetario.dart` | 78 | `ResumenLenteMonetario` | `resumen_lente_monetario_test.dart` |

## providers/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/providers/chat_provider.dart` | 124 | `ChatProvider` | `chat_provider_test.dart`, `chat_screen_test.dart`, `more_screen_test.dart`, +2 |
| `lib/providers/gasto_provider.dart` | 807 | `GastoProvider` | `database_helper_batch_and_async_test.dart`, `gasto_provider_budget_test.dart`, `gasto_provider_monetary_summary_test.dart`, +28 |
| `lib/providers/scan_queue_provider.dart` | 620 | `ScanQueueProvider` | `scan_queue_provider_test.dart`, `analysis_screen_redesign_test.dart`, `currency_calculator_screen_test.dart`, +20 |
| `lib/providers/settings_provider.dart` | 647 | `SettingsProvider` | `settings_provider_notifications_test.dart`, `settings_provider_rate_cache_test.dart`, `settings_provider_security_test.dart`, +25 |

## services/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/services/ai_insight_service.dart` | 1183 | `AiHiddenSignals`, `AiDashboardInsight`, `AiInsightService` | `dashboard_screen_test.dart`, `ai_insight_service_test.dart`, `chat_context_etapa0_test.dart`, +1 |
| `lib/services/ai_report_service.dart` | 129 | `AiReportException`, `AiReportService` | `chat_screen_test.dart`, `ai_report_service_test.dart` |
| `lib/services/category_classifier_service.dart` | 283 | `CategoryClassifierService` | `category_classifier_service_test.dart` |
| `lib/services/chat_context_builder.dart` | 424 | `ChatContextBuilder` | `chat_screen_test.dart`, `chat_context_etapa0_test.dart` |
| `lib/services/chat_signal_selector.dart` | 256 | `ChatSignalSelection`, `ChatSignalSelector` | `chat_context_etapa0_test.dart` |
| `lib/services/connectivity_service.dart` | 86 | `ConnectivityService` | `scan_queue_provider_test.dart`, `settings_provider_rate_cache_test.dart`, `main_screen_launch_action_test.dart`, +5 |
| `lib/services/document_scanner_service.dart` | 66 | `DocumentScannerService` | - |
| `lib/services/exchange_rate_service.dart` | 1155 | `ExchangeRatesData`, `PendingPurgeMutationType`, `PendingPurgeOperation`, `ExchangeRateService` | `gasto_provider_rate_cache_test.dart`, `settings_provider_rate_cache_test.dart`, `exchange_rate_service_cache_purge_test.dart`, +1 |
| `lib/services/export_service.dart` | 117 | `ExportService` | `export_service_test.dart` |
| `lib/services/image_service.dart` | 146 | `ImageService` | `sync_service_delete_account_test.dart` |
| `lib/services/local_ocr_service.dart` | 259 | `LocalOcrResult`, `OcrQualityScore`, `LocalOcrService` | `scan_screen_test.dart`, `local_ocr_service_test.dart`, `lote_4_ui_resilience_and_performance_test.dart` |
| `lib/services/notification_service.dart` | 833 | `PendingLaunchAction`, `NotificationService` | `settings_provider_notifications_test.dart`, `main_screen_launch_action_test.dart`, `intent_tray_notification_test.dart`, +2 |
| `lib/services/profile_avatar_service.dart` | 405 | `ProfileAvatarService` | `more_screen_test.dart`, `profile_avatar_service_test.dart` |
| `lib/services/receipt_photo_registry.dart` | 362 | `ReceiptPhotoRegistry` | `receipt_photo_registry_test.dart` |
| `lib/services/semantic_validator.dart` | 94 | `SemanticValidator`, `SemanticValidationResult` | `semantic_validator_test.dart` |
| `lib/services/sync_conflict_resolver.dart` | 132 | `AccionReconciliacion`, `ConflictoTombstoneRemoto`, `ConflictoEdicionConcurrente` | `sync_conflict_resolver_test.dart`, `sync_orchestration_test.dart` |
| `lib/services/sync_coordinator.dart` | 358 | `SyncTrigger`, `SyncStatus`, `SyncState`, `SyncCoordinator` | `dashboard_screen_test.dart`, `main_screen_launch_action_test.dart`, `more_screen_test.dart`, +1 |
| `lib/services/sync_service.dart` | 1329 | `SyncRunReport`, `SyncService` | `main_screen_launch_action_test.dart`, `reparar_tasas_dry_run_test.dart`, `sync_coordinator_test.dart`, +3 |
| `lib/services/update_service.dart` | 233 | `UpdateInfo`, `UpdateService` | `more_screen_test.dart`, `update_service_test.dart` |

## ui/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/ui/screens/analysis_screen.dart` | 871 | `AnalysisScreen` | `analysis_screen_redesign_test.dart`, `dashboard_category_budget_test.dart`, `lote_4_ui_resilience_and_performance_test.dart` |
| `lib/ui/screens/chat_screen.dart` | 1553 | `ChatSuggestion`, `ChatScreen` | `chat_screen_test.dart` |
| `lib/ui/screens/currency_calculator_screen.dart` | 970 | `TipoTasaCalculadora`, `CurrencyCalculatorScreen` | `currency_calculator_screen_test.dart`, `main_screen_launch_action_test.dart` |
| `lib/ui/screens/dashboard_screen.dart` | 1167 | `DashboardScreen` | `dashboard_screen_test.dart`, `smart_empty_state_and_lifecycle_test.dart` |
| `lib/ui/screens/expense_history_screen.dart` | 838 | `ExpenseHistoryScreen`, `ExpenseHistoryScreenState` | `dashboard_search_test.dart`, `expense_history_screen_test.dart`, `lote_4_ui_resilience_and_performance_test.dart`, +1 |
| `lib/ui/screens/main_screen.dart` | 909 | `MainScreen` | `main_screen_launch_action_test.dart`, `main_screen_no_auto_repair_test.dart`, `navigation_test.dart`, +1 |
| `lib/ui/screens/more_screen.dart` | 2100 | `MoreSubView`, `MoreScreen`, `MoreScreenState` | `more_screen_test.dart`, `more_screen_copy_and_dialogs_test.dart` |
| `lib/ui/screens/receipt_gallery_screen.dart` | 532 | `ReceiptGalleryScreen` | `receipt_gallery_screen_test.dart` |
| `lib/ui/screens/review_expense_screen.dart` | 5139 | `MetodoLiquidacionUsd`, `ReviewExpenseScreen` | `duplicate_expense_flow_test.dart`, `review_expense_price_history_test.dart`, `review_expense_screen_layout_test.dart`, +2 |
| `lib/ui/screens/scan_screen.dart` | 292 | `ScanScreen` | `scan_screen_test.dart` |
| `lib/ui/screens/shopping_list_screen.dart` | 231 | `ShoppingListScreen` | `shopping_list_screen_test.dart` |
| `lib/ui/widgets/ai_insight_card.dart` | 266 | `AiInsightCard` | `ai_insight_card_test.dart` |
| `lib/ui/widgets/app_bar_month_selector.dart` | 211 | `AppBarMonthSelector` | `app_bar_month_selector_test.dart` |
| `lib/ui/widgets/auth_modal_sheet.dart` | 331 | `AuthEmailDialog` | `auth_dialog_test.dart` |
| `lib/ui/widgets/bcv_legal_disclaimer_card.dart` | 87 | `BcvLegalDisclaimerCard` | - |
| `lib/ui/widgets/budget_bottom_sheet.dart` | 941 | `BudgetBottomSheet` | `budget_bottom_sheet_test.dart`, `sheet_geometry_test.dart` |
| `lib/ui/widgets/category_chart.dart` | 741 | `CategoryChart` | `dashboard_screen_test.dart`, `category_chart_test.dart`, `currency_display_test.dart`, +1 |
| `lib/ui/widgets/currency_lens_dropdown.dart` | 132 | `CurrencyLensDropdown` | `analysis_screen_redesign_test.dart` |
| `lib/ui/widgets/currency_radiography_card.dart` | 217 | `CurrencyRadiographyCard` | - |
| `lib/ui/widgets/daily_evolution_card.dart` | 378 | `DailyEvolutionCard` | `daily_evolution_card_test.dart` |
| `lib/ui/widgets/expense_card.dart` | 704 | `ExpenseCard` | `duplicate_expense_flow_test.dart`, `currency_display_test.dart`, `expense_card_test.dart` |
| `lib/ui/widgets/global_scan_queue_banner.dart` | 645 | `GlobalScanQueueBanner` | `global_scan_queue_banner_test.dart` |
| `lib/ui/widgets/month_selector_bar.dart` | 241 | `MonthSelectorBar` | `month_selector_bar_test.dart` |
| `lib/ui/widgets/more/more_rates_card.dart` | 254 | `MoreRatesCard` | - |
| `lib/ui/widgets/more/more_tools_grid.dart` | 175 | `MoreToolsGrid` | - |
| `lib/ui/widgets/pending_expense_card.dart` | 273 | `PendingExpenseCard` | `lote_4_ui_resilience_and_performance_test.dart` |
| `lib/ui/widgets/purchase_radiography_card.dart` | 297 | `PurchaseRadiographyCard` | - |
| `lib/ui/widgets/receipt_viewer_dialog.dart` | 273 | `ReceiptViewerDialog` | `receipt_viewer_dialog_test.dart` |
| `lib/ui/widgets/summary_card.dart` | 568 | `SummaryCard` | `dashboard_category_budget_test.dart`, `currency_display_test.dart`, `lote_4_ui_resilience_and_performance_test.dart`, +1 |
| `lib/ui/widgets/update_dialog.dart` | 150 | `UpdateDialog` | - |
| `lib/ui/widgets/voice_expense_sheet.dart` | 959 | `VoiceExpenseSheet` | `sheet_geometry_test.dart`, `voice_expense_sheet_test.dart` |

## (raiz)/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/firebase_options.dart` | 34 | `DefaultFirebaseOptions` | - |
| `lib/main.dart` | 72 | `GastoScanApp` | - |
