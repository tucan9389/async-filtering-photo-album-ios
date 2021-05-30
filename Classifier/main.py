import os, random, shutil, time
random.seed(777)

def imgfilepaths_without_target_id(id_to_imagefilenames, target_id, img_num_each_class=2):
    result_img_paths = []
    for id in id_to_imagefilenames:
        if id == target_id:
            continue
        img_filenames = id_to_imagefilenames[id][:img_num_each_class]
        img_paths = list(map(lambda x: os.path.join(id, x), img_filenames))
        result_img_paths += img_paths
    return result_img_paths


if __name__ == '__main__':
    imagenet_dataset_path = "/Users/tucan9389/Downloads/imagenet-object-localization-challenge"
    label_map_txt_path = os.path.join(imagenet_dataset_path, "LOC_synset_mapping.txt")
    dataset_dir_path = os.path.join(imagenet_dataset_path, "ILSVRC/Data/CLS-LOC/train")

    id_to_label = { }
    lines = open(label_map_txt_path, 'r').read().split("\n")
    for line in lines:
        words = line.split()
        if len(words) == 0:
            continue
        key = words[0]
        del words[0]
        label = (" ".join(words)).split(",")[0]
        label = label.replace(" ", "-")
        id_to_label[key] = label

    print(len(id_to_label))
    class_ids = os.listdir(dataset_dir_path)
    print(len(class_ids))

    print(id_to_label)

    id_to_imagefilenames = {}

    for target_id in id_to_label:
        img_dir_path = os.path.join(dataset_dir_path, target_id)
        # print(target_id, len(os.listdir(img_dir_path)))
        img_filenames = os.listdir(img_dir_path)
        img_filenames = list(filter(lambda x: not x.startswith("."), img_filenames))
        random.shuffle(img_filenames)
        id_to_imagefilenames[target_id] = img_filenames

    current_path = os.getcwd()
    print(current_path)
    tmp_dataset_path = os.path.join(current_path, "tmp")

    output_mlmodel_dir_name = "outputs_mlmodel2"
    output_mlmodel_cache_dir_name = "outputs_mlmodel"
    mlmodel_dir_path = os.path.join(current_path, output_mlmodel_dir_name)
    mlmodel_cache_dir_path = os.path.join(current_path, output_mlmodel_cache_dir_name) if output_mlmodel_cache_dir_name is not None else None
    if not os.path.exists(output_mlmodel_dir_name):
        os.mkdir(output_mlmodel_dir_name)
    if os.path.exists(tmp_dataset_path):
        shutil.rmtree(tmp_dataset_path)

    before_mlmodel_filenames = os.listdir(mlmodel_dir_path)
    before_mlmodel_filenames = list(filter(lambda x: x.endswith(".mlmodel"), before_mlmodel_filenames))
    before_mlmodel_filenames = list(map(lambda x: x.replace(".mlmodel", ""), before_mlmodel_filenames))
    precisions = list(map(lambda x: x.split("_")[-1], before_mlmodel_filenames))
    before_target_labels = list(map(lambda x: x[0].replace(f"_{x[1]}", ""), zip(before_mlmodel_filenames, precisions)))
    before_target_labels = list(map(lambda x: x.replace("_or_not", ""), before_target_labels))
    print("len(before_target_labels):", len(before_target_labels))

    cache_filenames = os.listdir(mlmodel_cache_dir_path)
    cache_mlmodel_filenames = list(filter(lambda x: x.endswith(".mlmodel"), cache_filenames))
    cache_log_filenames = list(filter(lambda x: x.endswith(".out"), cache_filenames))
    for t_index, target_id in enumerate(class_ids):
        target_label = id_to_label[target_id]
        if target_label in before_target_labels:
            continue
        print("-" * 30, f"{t_index}-{target_label}", "-" * 30)
        cached_mlmodel_filenames = list(filter(lambda x: target_label in x, cache_mlmodel_filenames))
        cached_log_filenames = list(filter(lambda x: target_label in x, cache_log_filenames))
        if len(cached_mlmodel_filenames) == 1 and len(cached_log_filenames) == 1:
            cached_mlmodel_filename = cached_mlmodel_filenames[0]
            cached_log_filename = cached_log_filenames[0]
            src_mlmodel_path = os.path.join(mlmodel_cache_dir_path, cached_mlmodel_filename)
            src_log_path = os.path.join(mlmodel_cache_dir_path, cached_log_filename)
            dst_mlmodel_path = os.path.join(mlmodel_dir_path, cached_mlmodel_filename)
            dst_log_path = os.path.join(mlmodel_dir_path, cached_log_filename)
            shutil.copyfile(src_mlmodel_path, dst_mlmodel_path)
            shutil.copyfile(src_log_path, dst_log_path)
            print(f" >> COPIED MLMODEL AND LOG FILE - {target_label}")
            continue

        os.mkdir(tmp_dataset_path)

        target_img_filenames = id_to_imagefilenames[target_id]
        target_img_filepaths = list(map(lambda x: os.path.join(target_id, x), target_img_filenames))
        not_target_img_filepaths = imgfilepaths_without_target_id(id_to_imagefilenames, target_id)

        print(f" >> DATASET CREATING START - {target_label}")
        target_dir_path = os.path.join(tmp_dataset_path, target_label)
        not_target_dir_path = os.path.join(tmp_dataset_path, "not")
        if not os.path.exists(target_dir_path):
            os.mkdir(target_dir_path)
        if not os.path.exists(not_target_dir_path):
            os.mkdir(not_target_dir_path)


        for img_path in target_img_filepaths:
            src_img_path = os.path.join(dataset_dir_path, img_path)
            dst_img_path = os.path.join(target_dir_path, img_path.split("/")[-1])
            shutil.copyfile(src_img_path, dst_img_path)
        for img_path in not_target_img_filepaths:
            src_img_path = os.path.join(dataset_dir_path, img_path)
            dst_img_path = os.path.join(not_target_dir_path, img_path.split("/")[-1])
            shutil.copyfile(src_img_path, dst_img_path)
        print(f" >> DATASET CREATING DONE - {target_label}")

        print(f" >> TRAINING START - {target_label}")
        # tmp_dataset_path
        mlmodel_filename = f"{target_label}_or_not.mlmodel"
        mlmodel_filepath = os.path.join(mlmodel_dir_path, mlmodel_filename)
        log_filepath = os.path.join(mlmodel_dir_path, f"{target_label}_or_not.out")
        maxIterations = 50

        createml_training_command = f'swift make_classifier.swift "{tmp_dataset_path}" "{mlmodel_filepath}" {maxIterations} > "{log_filepath}"'
        print("  $", createml_training_command)
        try:
            os.system(createml_training_command)
        except:
            try:
                time.sleep(60)
                os.system(createml_training_command)
            except:
                try:
                    time.sleep(60)
                    os.system(createml_training_command)
                except:
                    exit(1)

        print(f" >> TRAINING DONE - {target_label}")

        s_idx = -1
        lines = open(log_filepath, 'r').read().split("\n")
        for idx, line in enumerate(lines):
            if "******PRECISION RECALL******" in line:
                s_idx = idx
            elif "Accuracy:" in line:
                accuracy = line.split()[1]
        if lines[s_idx + 3].split()[0] == 'not':
            precision, recall = lines[s_idx + 4].split()[1], lines[s_idx + 4].split()[2]
        else:
            precision, recall = lines[s_idx + 3].split()[1], lines[s_idx + 3].split()[2]

        precision, recall = precision.split(".")[0], recall.split(".")[0]
        accuracy = accuracy.split(".")[0]
        print(" >> accuracy:", accuracy, "precision:", precision, "recall:", recall)

        src_mlmodel_filepath = mlmodel_filepath
        mlmodel_filename = f"{target_label}_or_not_{precision}.mlmodel"
        mlmodel_filepath = os.path.join(mlmodel_dir_path, mlmodel_filename)
        dst_mlmodel_filepath = mlmodel_filepath
        shutil.move(src_mlmodel_filepath, dst_mlmodel_filepath)

        if os.path.exists(tmp_dataset_path):
            shutil.rmtree(tmp_dataset_path)
