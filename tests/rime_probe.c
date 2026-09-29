// 用真实 librime（含 librime-lua 插件）驱动输入，输出候选词，供 integration_test.lua 断言
// 用法：rime_probe <user_data_dir> <schema_id> [option=0|1 ...] -- <keys> [<keys> ...]
// 输出：每个按键序列一行，"keys\t候选1\t候选2..."；部署失败时退出码为 1
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rime_api.h"

#define MAX_CANDIDATES 50

int main(int argc, char** argv) {
  if (argc < 4) {
    fprintf(stderr, "usage: %s <user_data_dir> <schema_id> [option=0|1 ...] -- <keys>...\n", argv[0]);
    return 2;
  }
  RimeApi* rime = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.shared_data_dir = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport";
  traits.user_data_dir = argv[1];
  traits.app_name = "rime.probe";
  traits.min_log_level = 2;  // 只输出 ERROR 及以上，供测试检查
  traits.log_dir = "";       // 写到 stderr
  rime->setup(&traits);
  rime->initialize(&traits);
  if (rime->start_maintenance(True)) rime->join_maintenance_thread();

  RimeSessionId session = rime->create_session();
  if (!rime->select_schema(session, argv[2])) {
    fprintf(stderr, "cannot select schema: %s\n", argv[2]);
    return 1;
  }

  int i = 3;
  for (; i < argc && strcmp(argv[i], "--") != 0; i++) {
    char* eq = strchr(argv[i], '=');
    if (!eq) continue;
    *eq = '\0';
    rime->set_option(session, argv[i], atoi(eq + 1) ? True : False);
  }

  for (i++; i < argc; i++) {
    rime->clear_composition(session);
    rime->simulate_key_sequence(session, argv[i]);
    printf("%s", argv[i]);
    RimeCandidateListIterator it = {0};
    if (rime->candidate_list_begin(session, &it)) {
      for (int n = 0; n < MAX_CANDIDATES && rime->candidate_list_next(&it); n++)
        printf("\t%s", it.candidate.text);
      rime->candidate_list_end(&it);
    }
    printf("\n");
  }

  rime->destroy_session(session);
  rime->finalize();
  return 0;
}
