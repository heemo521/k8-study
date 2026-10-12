import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/engine/labs.dart';

void main() {
  test('guidance fades with completed runs', () {
    expect(guidanceFor(0), LabGuidance.worked);
    expect(guidanceFor(1), LabGuidance.partial);
    expect(guidanceFor(2), LabGuidance.solo);
    expect(guidanceFor(9), LabGuidance.solo);
  });

  test('partial hint keeps the verb, hides the rest', () {
    expect(
      partialHint('kubectl rollout undo deployment/nginx-deployment'),
      'kubectl rollout undo …',
    );
    expect(
      partialHint('kubectl drain --ignore-daemonsets my-node'),
      'kubectl drain …',
    );
    expect(partialHint('kubectl get deployments'), 'kubectl get …');
    // Never gives away the whole command.
    expect(partialHint('kubectl rollout status'), 'kubectl rollout …');
    expect(partialHint('kubectl version'), 'kubectl …');
  });
}
