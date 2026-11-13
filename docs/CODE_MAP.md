# Mapa de Código (generado)

> Archivo generado por `node scripts/gen_code_map.js`. No lo edites a mano.
> Regenerar tras tocar `lib/` o `test/`: `node scripts/gen_code_map.js`.
> El hook de pre-commit lo actualiza y lo añade al commit.

## Resumen

| Capa | Archivos | Líneas |
|---|---|---|
| `core/` | 8 | 932 |
| `data/` | 12 | 4239 |
| `domain/` | 10 | 1816 |
| `providers/` | 4 | 1960 |
| `services/` | 13 | 4438 |
| `ui/` | 31 | 18924 |
| `(raiz)/` | 2 | 106 |
| **Total** | **80** | **32415** |

## core/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/core/constants/app_colors.dart` | 69 | `AppColors` | `app_colors_budget_progress_test.dart`, `dashboard_category_budget_test.dart`, `more_screen_test.dart`, +5 |
| `lib/core/constants/app_constants.dart` | 261 | `AppConstants` | `categoria_model_test.dart`, `gasto_provider_rate_cache_test.dart`, `settings_provider_notifications_test.dart`, +10 |
| `lib/core/theme/app_theme.dart` | 151 | `AppTheme` | - |
| `lib/core/utils/amount_parser.dart` | 98 | - | `amount_parser_test.dart` |
| `lib/core/utils/currency_formatter.dart` | 182 | `CurrencyFormatter` | `analysis_screen_redesign_test.dart`, `dashboard_category_budget_test.dart`, `category_chart_test.dart`, +1 |
| `lib/core/utils/date_formatter.dart` | 35 | `DateFormatter` | `analysis_screen_redesign_test.dart`, `smart_empty_state_and_lifecycle_test.dart` |
| `lib/core/utils/image_hash_service.dart` | 123 | `ImageHashService` | `image_hash_service_test.dart` |
| `lib/core/utils/uuid_generator.dart` | 13 | `UuidGenerator` | `uuid_generator_test.dart` |

## data/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/data/datasources/local/database_helper.dart` | 2229 | `UnitPriceRef`, `PriceHistory`, `DatabaseHelper` | `database_helper_batch_and_async_test.dart`, `database_helper_category_test.dart`, `database_helper_fts_test.dart`, +33 |
| `lib/data/datasources/remote/firestore_gastos_remote_data_source.dart` | 72 | `FirestoreGastosRemoteDataSource` | - |
| `lib/data/datasources/remote/gastos_remote_data_source.dart` | 26 | `RemoteGasto`, `RemotePresupuesto`, `GastosRemoteDataSource` | `reparar_tasas_dry_run_test.dart`, `sync_orchestration_test.dart` |
| `lib/data/datasources/remote/gemini_service.dart` | 675 | `GeminiService` | `database_helper_batch_and_async_test.dart`, `chat_screen_test.dart`, `gemini_service_security_test.dart`, +2 |
| `lib/data/models/categoria_model.dart` | 69 | `CategoriaModel`, `CategoryModel` | `database_helper_category_test.dart`, `categoria_model_test.dart` |
| `lib/data/models/gasto_firestore_mapper.dart` | 77 | `GastoFirestoreMapper` | `gasto_firestore_mapper_test.dart` |
| `lib/data/models/gasto_model.dart` | 215 | `GastoModel` | `database_helper_batch_and_async_test.dart`, `database_helper_in_memory_harness_test.dart`, `contenido_negocio_identico_test.dart`, +30 |
| `lib/data/models/gemini_extraction_result.dart` | 381 | `GeminiExtractionResult` | `gemini_extraction_result_test.dart`, `scan_queue_provider_test.dart`, `review_expense_price_history_test.dart`, +4 |
| `lib/data/models/item_gasto_model.dart` | 130 | `OrigenCategoria`, `ItemGastoModel` | `database_helper_in_memory_harness_test.dart`, `database_helper_price_history_test.dart`, `contenido_negocio_identico_test.dart`, +16 |
| `lib/data/models/presupuesto_remoto_model.dart` | 75 | `PresupuestoRemotoModel` | `presupuesto_remoto_model_test.dart`, `sync_orchestration_test.dart` |
| `lib/data/models/shopping_item_model.dart` | 53 | `ShoppingItemModel` | `shopping_item_model_test.dart`, `scan_queue_provider_test.dart`, `chat_screen_test.dart`, +2 |
| `lib/data/repositories/gasto_repository.dart` | 237 | `GastoRepository` | `database_helper_batch_and_async_test.dart`, `gasto_provider_monetary_summary_test.dart`, `gasto_provider_rate_cache_test.dart`, +6 |

## domain/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/domain/diagnostics/rm03_copy_strategy.dart` | 108 | `Rm03DiagnosticIoException`, `Rm03CopyStrategy`, `FileRm03CopyStrategy` | `rm03_diagnostic_protocol_test.dart` |
| `lib/domain/diagnostics/rm03_diagnostic_protocol.dart` | 710 | `Rm03DiagnosticSecurityException`, `Rm03DiagnosticSchemaException`, `Rm03QueryResult`, `Rm03DiagnosticReport`, +1 | `rm03_diagnostic_protocol_test.dart` |
| `lib/domain/finance/savings_health_calculator.dart` | 54 | `SavingsHealthCalculator` | `savings_health_calculator_test.dart` |
| `lib/domain/finance/savings_health_models.dart` | 47 | `SavingsGoalStatus`, `SavingsHealthSnapshot` | `savings_health_calculator_test.dart` |
| `lib/domain/monetary/expense_tuple.dart` | 347 | `ExpenseTuple`, `TupleFailureCode`, `TupleBuildResult`, `TupleBuildSuccess`, +1 | `build_new_expense_tuple_test.dart` |
| `lib/domain/monetary/metodo_liquidacion.dart` | 12 | `MetodoLiquidacion` | `build_new_expense_tuple_test.dart` |
| `lib/domain/monetary/monetary_resolution.dart` | 246 | `EstadoValorMonetario`, `EstadoTasaPersistida`, `ValorMonetarioResuelto` | `contenido_negocio_identico_test.dart`, `resolve_persisted_expense_test.dart` |
| `lib/domain/monetary/rate_market.dart` | 85 | `RateMarket`, `EstadoTasaMoneda`, `RateSourceId` | `build_new_expense_tuple_test.dart`, `rate_market_test.dart`, `rate_quote_input_test.dart` |
| `lib/domain/monetary/rate_quote_input.dart` | 129 | `QuoteValidationError`, `RateQuoteInput` | `build_new_expense_tuple_test.dart`, `rate_quote_input_test.dart` |
| `lib/domain/monetary/resumen_lente_monetario.dart` | 78 | `ResumenLenteMonetario` | `resumen_lente_monetario_test.dart` |

## providers/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/providers/chat_provider.dart` | 50 | `ChatProvider` | `chat_provider_test.dart`, `chat_screen_test.dart`, `more_screen_test.dart`, +1 |
| `lib/providers/gasto_provider.dart` | 788 | `GastoProvider` | `database_helper_batch_and_async_test.dart`, `gasto_provider_budget_test.dart`, `gasto_provider_monetary_summary_test.dart`, +27 |
| `lib/providers/scan_queue_provider.dart` | 620 | `ScanQueueProvider` | `scan_queue_provider_test.dart`, `analysis_screen_redesign_test.dart`, `currency_calculator_screen_test.dart`, +19 |
| `lib/providers/settings_provider.dart` | 502 | `SettingsProvider` | `settings_provider_notifications_test.dart`, `settings_provider_rate_cache_test.dart`, `settings_provider_security_test.dart`, +24 |

## services/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/services/category_classifier_service.dart` | 283 | `CategoryClassifierService` | `category_classifier_service_test.dart` |
| `lib/services/connectivity_service.dart` | 86 | `ConnectivityService` | `scan_queue_provider_test.dart`, `main_screen_launch_action_test.dart`, `connectivity_service_test.dart`, +1 |
| `lib/services/document_scanner_service.dart` | 66 | `DocumentScannerService` | - |
| `lib/services/exchange_rate_service.dart` | 1097 | `ExchangeRatesData`, `PendingPurgeMutationType`, `PendingPurgeOperation`, `ExchangeRateService` | `gasto_provider_rate_cache_test.dart`, `settings_provider_rate_cache_test.dart`, `exchange_rate_service_cache_purge_test.dart`, +1 |
| `lib/services/export_service.dart` | 117 | `ExportService` | `export_service_test.dart` |
| `lib/services/image_service.dart` | 139 | `ImageService` | `sync_service_delete_account_test.dart` |
| `lib/services/local_ocr_service.dart` | 259 | `LocalOcrResult`, `OcrQualityScore`, `LocalOcrService` | `scan_screen_test.dart`, `local_ocr_service_test.dart`, `lote_4_ui_resilience_and_performance_test.dart` |
| `lib/services/notification_service.dart` | 712 | `PendingLaunchAction`, `NotificationService` | `settings_provider_notifications_test.dart`, `main_screen_launch_action_test.dart`, `intent_tray_notification_test.dart`, +1 |
| `lib/services/semantic_validator.dart` | 81 | `SemanticValidator`, `SemanticValidationResult` | `semantic_validator_test.dart` |
| `lib/services/sync_conflict_resolver.dart` | 132 | `AccionReconciliacion`, `ConflictoTombstoneRemoto`, `ConflictoEdicionConcurrente` | `sync_conflict_resolver_test.dart`, `sync_orchestration_test.dart` |
| `lib/services/sync_coordinator.dart` | 265 | `SyncTrigger`, `SyncStatus`, `SyncState`, `SyncCoordinator` | `main_screen_launch_action_test.dart`, `sync_coordinator_test.dart` |
| `lib/services/sync_service.dart` | 1042 | `SyncService` | `main_screen_launch_action_test.dart`, `reparar_tasas_dry_run_test.dart`, `sync_coordinator_test.dart`, +3 |
| `lib/services/update_service.dart` | 159 | `UpdateInfo`, `UpdateService` | `update_service_test.dart` |

## ui/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/ui/screens/analysis_screen.dart` | 871 | `AnalysisScreen` | `analysis_screen_redesign_test.dart`, `dashboard_category_budget_test.dart`, `lote_4_ui_resilience_and_performance_test.dart` |
| `lib/ui/screens/chat_screen.dart` | 1264 | `ChatSuggestion`, `ChatScreen` | `chat_screen_test.dart` |
| `lib/ui/screens/currency_calculator_screen.dart` | 857 | `TipoTasaCalculadora`, `CurrencyCalculatorScreen` | `currency_calculator_screen_test.dart` |
| `lib/ui/screens/dashboard_screen.dart` | 775 | `DashboardScreen` | `dashboard_screen_test.dart`, `smart_empty_state_and_lifecycle_test.dart` |
| `lib/ui/screens/expense_history_screen.dart` | 827 | `ExpenseHistoryScreen`, `ExpenseHistoryScreenState` | `dashboard_search_test.dart`, `expense_history_screen_test.dart`, `lote_4_ui_resilience_and_performance_test.dart`, +1 |
| `lib/ui/screens/main_screen.dart` | 706 | `MainScreen` | `main_screen_launch_action_test.dart`, `main_screen_no_auto_repair_test.dart`, `navigation_test.dart`, +1 |
| `lib/ui/screens/more_screen.dart` | 1606 | `MoreSubView`, `MoreScreen`, `MoreScreenState` | `more_screen_test.dart`, `more_screen_copy_and_dialogs_test.dart` |
| `lib/ui/screens/receipt_gallery_screen.dart` | 532 | `ReceiptGalleryScreen` | `receipt_gallery_screen_test.dart` |
| `lib/ui/screens/review_expense_screen.dart` | 3694 | `MetodoLiquidacionUsd`, `ReviewExpenseScreen` | `review_expense_price_history_test.dart`, `review_expense_screen_layout_test.dart`, `review_expense_token_test.dart`, +1 |
| `lib/ui/screens/scan_screen.dart` | 292 | `ScanScreen` | `scan_screen_test.dart` |
| `lib/ui/screens/shopping_list_screen.dart` | 231 | `ShoppingListScreen` | `shopping_list_screen_test.dart` |
| `lib/ui/widgets/ai_insight_card.dart` | 261 | `AiInsightCard` | `ai_insight_card_test.dart` |
| `lib/ui/widgets/app_bar_month_selector.dart` | 211 | `AppBarMonthSelector` | `app_bar_month_selector_test.dart` |
| `lib/ui/widgets/auth_modal_sheet.dart` | 331 | `AuthEmailDialog` | `auth_dialog_test.dart` |
| `lib/ui/widgets/bcv_legal_disclaimer_card.dart` | 87 | `BcvLegalDisclaimerCard` | - |
| `lib/ui/widgets/budget_bottom_sheet.dart` | 941 | `BudgetBottomSheet` | `budget_bottom_sheet_test.dart`, `sheet_geometry_test.dart` |
| `lib/ui/widgets/category_chart.dart` | 741 | `CategoryChart` | `dashboard_screen_test.dart`, `category_chart_test.dart`, `currency_display_test.dart`, +1 |
| `lib/ui/widgets/currency_lens_dropdown.dart` | 132 | `CurrencyLensDropdown` | `analysis_screen_redesign_test.dart` |
| `lib/ui/widgets/currency_radiography_card.dart` | 217 | `CurrencyRadiographyCard` | - |
| `lib/ui/widgets/daily_evolution_card.dart` | 378 | `DailyEvolutionCard` | `daily_evolution_card_test.dart` |
| `lib/ui/widgets/expense_card.dart` | 534 | `ExpenseCard` | `currency_display_test.dart`, `expense_card_test.dart` |
| `lib/ui/widgets/global_scan_queue_banner.dart` | 647 | `GlobalScanQueueBanner` | `global_scan_queue_banner_test.dart` |
| `lib/ui/widgets/month_selector_bar.dart` | 241 | `MonthSelectorBar` | `month_selector_bar_test.dart` |
| `lib/ui/widgets/more/more_rates_card.dart` | 254 | `MoreRatesCard` | - |
| `lib/ui/widgets/more/more_tools_grid.dart` | 175 | `MoreToolsGrid` | - |
| `lib/ui/widgets/pending_expense_card.dart` | 273 | `PendingExpenseCard` | `lote_4_ui_resilience_and_performance_test.dart` |
| `lib/ui/widgets/purchase_radiography_card.dart` | 297 | `PurchaseRadiographyCard` | - |
| `lib/ui/widgets/receipt_viewer_dialog.dart` | 273 | `ReceiptViewerDialog` | `receipt_viewer_dialog_test.dart` |
| `lib/ui/widgets/summary_card.dart` | 568 | `SummaryCard` | `dashboard_category_budget_test.dart`, `currency_display_test.dart`, `lote_4_ui_resilience_and_performance_test.dart`, +1 |
| `lib/ui/widgets/update_dialog.dart` | 150 | `UpdateDialog` | - |
| `lib/ui/widgets/voice_expense_sheet.dart` | 558 | `VoiceExpenseSheet` | `sheet_geometry_test.dart`, `voice_expense_sheet_test.dart` |

## (raiz)/

| Archivo | Líneas | Símbolos | Pruebas |
|---|---|---|---|
| `lib/firebase_options.dart` | 34 | `DefaultFirebaseOptions` | - |
| `lib/main.dart` | 72 | `GastoScanApp` | - |
