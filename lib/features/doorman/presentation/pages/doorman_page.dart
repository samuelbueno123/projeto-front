import 'package:flutter/material.dart';

import '../../../home/data/home_service.dart';

class DoormanPage extends StatefulWidget {
  const DoormanPage({
    super.key,
    required this.token,
    required this.userName,
    required this.onLogout,
  });

  final String? token;
  final String? userName;
  final Future<void> Function() onLogout;

  @override
  State<DoormanPage> createState() => _DoormanPageState();
}

class _DoormanPageState extends State<DoormanPage> {
  late final HomeService _api;
  List<Map<String, dynamic>> _condominiums = [];
  Map<String, dynamic>? _selectedCondominium;
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = HomeService(token: widget.token);
    _loadCondominiums();
  }

  Future<void> _loadCondominiums() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final memberships = await _api.get('/memberships/my');
      final list = (memberships as List).cast<Map<String, dynamic>>();

      final condos = <Map<String, dynamic>>[];
      for (final m in list) {
        final condoId = m['condominiumId'];
        if (condoId != null) {
          try {
            final condo = await _api.get('/condominiums/$condoId');
            condos.add(condo as Map<String, dynamic>);
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _condominiums = condos;
          if (_condominiums.isNotEmpty) {
            _selectedCondominium = _condominiums.first;
            _loadPackages();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar condomínios associados.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPackages() async {
    if (_selectedCondominium == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final condoId = _selectedCondominium!['id'];
      final response = await _api.get(
        '/packages?condominiumId=$condoId&page=0&size=100&sort=id,desc',
      );

      List<Map<String, dynamic>> packages = [];
      if (response is Map && response['content'] is List) {
        packages = (response['content'] as List).cast<Map<String, dynamic>>();
      } else if (response is List) {
        packages = response.cast<Map<String, dynamic>>();
      }

      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar encomendas.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePackageStatus(int packageId, String action) async {
    try {
      await _api.send('PATCH', '/packages/$packageId/$action');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status atualizado com sucesso.')),
        );
        _loadPackages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _registerReceivedPackage() async {
    final descriptionController = TextEditingController();
    final recipientIdController = TextEditingController();
    final unitIdController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar Encomenda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                TextField(
                  controller: recipientIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID do Morador (Opcional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: unitIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID da Unidade (Opcional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      try {
        final body = {
          'description': descriptionController.text,
          if (recipientIdController.text.isNotEmpty)
            'recipientId': int.tryParse(recipientIdController.text),
          if (unitIdController.text.isNotEmpty)
            'unitId': int.tryParse(unitIdController.text),
        };
        await _api.send('POST', '/packages', body: body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Encomenda registrada.')),
          );
        }
        _loadPackages();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Widget _buildStatusAction(Map<String, dynamic> pkg) {
    final status = pkg['status'] as String?;
    final id = pkg['id'] as int;

    if (status == 'EXPECTED') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            tooltip: 'Receber',
            onPressed: () => _updatePackageStatus(id, 'receive'),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Cancelar',
            onPressed: () => _updatePackageStatus(id, 'cancel'),
          ),
        ],
      );
    } else if (status == 'RECEIVED') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.blue),
            tooltip: 'Notificar',
            onPressed: () => _updatePackageStatus(id, 'notify'),
          ),
          IconButton(
            icon: const Icon(Icons.hail, color: Colors.green),
            tooltip: 'Entregar (Retirada)',
            onPressed: () => _updatePackageStatus(id, 'pickup'),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_return, color: Colors.orange),
            tooltip: 'Devolver',
            onPressed: () => _updatePackageStatus(id, 'return'),
          ),
        ],
      );
    } else if (status == 'NOTIFIED') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.hail, color: Colors.green),
            tooltip: 'Entregar (Retirada)',
            onPressed: () => _updatePackageStatus(id, 'pickup'),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_return, color: Colors.orange),
            tooltip: 'Devolver',
            onPressed: () => _updatePackageStatus(id, 'return'),
          ),
        ],
      );
    }

    return Text(
      status ?? 'Desconhecido',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portaria - Encomendas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Sair',
          ),
        ],
      ),
      floatingActionButton: _selectedCondominium != null
          ? FloatingActionButton(
              onPressed: _registerReceivedPackage,
              tooltip: 'Registrar Encomenda',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          if (_condominiums.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: _selectedCondominium,
                decoration: const InputDecoration(
                  labelText: 'Condomínio',
                  border: OutlineInputBorder(),
                ),
                items: _condominiums.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c['name']?.toString() ?? 'Sem nome'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCondominium = val;
                  });
                  _loadPackages();
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _condominiums.isEmpty
                ? const Center(child: Text('Nenhum condomínio associado.'))
                : _packages.isEmpty
                ? const Center(child: Text('Nenhuma encomenda encontrada.'))
                : ListView.builder(
                    itemCount: _packages.length,
                    itemBuilder: (context, index) {
                      final pkg = _packages[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            pkg['description']?.toString() ?? 'Sem descrição',
                          ),
                          subtitle: Text(
                            'ID: ${pkg['id']} | Unidade: ${pkg['unitId'] ?? 'N/A'}',
                          ),
                          trailing: _buildStatusAction(pkg),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
