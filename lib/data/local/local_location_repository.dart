import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';

@DevOnly('Backed by the college workbook seed (15 locations).')
class LocalLocationRepository implements LocationRepository {
  const LocalLocationRepository(this.locations);

  final List<Location> locations;

  @override
  Future<Location?> byId(String id) async {
    for (final l in locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  @override
  Future<List<Location>> all() async => locations;
}