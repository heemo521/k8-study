import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/engine/command_grading.dart';

void main() {
  bool m(String typed, String accepted) => commandMatches(typed, [accepted]);

  test('exact and whitespace-insensitive', () {
    const a = 'kubectl scale deployment/web --replicas=3';
    expect(m(a, a), isTrue);
    expect(m('  kubectl   scale deployment/web  --replicas=3 ', a), isTrue);
    expect(m(r'$ kubectl scale deployment/web --replicas=3', a), isTrue);
  });

  test('k alias, type/name, short names and plurals', () {
    const a = 'kubectl scale deployment/web --replicas=3';
    expect(m('k scale deployment web --replicas=3', a), isTrue);
    expect(m('kubectl scale deploy web --replicas=3', a), isTrue);
    expect(m('kubectl scale deployments/web --replicas=3', a), isTrue);
    expect(m('kubectl get po', 'kubectl get pods'), isTrue);
    expect(m('kubectl get svc', 'kubectl get services'), isTrue);
  });

  test('flag order, = or space, short and long forms', () {
    const a = 'kubectl run nginx --image=nginx -n mynamespace';
    expect(m('kubectl run nginx -n mynamespace --image nginx', a), isTrue);
    expect(
      m('kubectl run nginx --namespace=mynamespace --image=nginx', a),
      isTrue,
    );
    expect(m('kubectl -n mynamespace run nginx --image=nginx', a), isTrue);
    expect(
      m('kubectl get pods -A', 'kubectl get pods --all-namespaces'),
      isTrue,
    );
  });

  test('combined boolean shorts and the -- separator', () {
    const a = 'kubectl exec --stdin --tty my-pod -- /bin/sh';
    expect(m('kubectl exec -it my-pod -- /bin/sh', a), isTrue);
    expect(m('kubectl exec -i -t my-pod -- /bin/sh', a), isTrue);
    expect(m('kubectl exec -it my-pod -- sh', a), isFalse);
    expect(m('kubectl exec my-pod -- /bin/sh', a), isFalse);
  });

  test('boolean flags do not swallow the next word', () {
    const a = 'kubectl drain --ignore-daemonsets my-node';
    expect(m('kubectl drain my-node --ignore-daemonsets', a), isTrue);
    expect(
      m('kubectl logs --previous my-pod', 'kubectl logs my-pod --previous'),
      isTrue,
    );
  });

  test('quotes around one word are ignored', () {
    expect(
      m(
        "kubectl create deployment nginx --image='nginx'",
        'kubectl create deployment nginx --image=nginx',
      ),
      isTrue,
    );
  });

  test('wrong values, names, verbs and missing flags fail', () {
    const a = 'kubectl rollout undo deployment/web --to-revision=2';
    expect(
      m('kubectl rollout undo deployment/web --to-revision=3', a),
      isFalse,
    );
    expect(
      m('kubectl rollout undo deployment/api --to-revision=2', a),
      isFalse,
    );
    expect(
      m('kubectl rollout status deployment/web --to-revision=2', a),
      isFalse,
    );
    expect(m('kubectl rollout undo deployment/web', a), isFalse);
    expect(m('', a), isFalse);
    expect(
      m(
        'kubectl taint nodes node1 key1=value1:NoSchedule',
        'kubectl taint nodes node1 key1=value1:NoSchedule-',
      ),
      isFalse,
    );
  });
}
